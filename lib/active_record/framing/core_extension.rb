# frozen_string_literal: true

require "active_record/framing/default"
require "active_record/framing/named"

module ActiveRecord
  module Framing

    def self.prepended(subclass)
      subclass.singleton_class.class_eval do
        alias_method :unframed_all, :all
        # NOTE: not for 4.2
        alias_method :unframed_scope_for_association, :scope_for_association if subclass.respond_to?(:scope_for_association)

        # Subclasses need to be able to call its parent's
        protected :relation
      end

      subclass.include Default
      subclass.extend Named
      subclass.include AttributeMethods
      subclass.extend ClassMethods
    end

    def self.disable
      old_value = FrameRegistry.instance.disabled
      FrameRegistry.instance.disabled = true
      yield if block_given?
    ensure
      FrameRegistry.instance.disabled = old_value
    end

    def self.disabled?
      FrameRegistry.instance.disabled == true
    end

    module ClassMethods # :nodoc:
      def current_frame(skip_inherited_frame: false)
        FrameRegistry.value_for(:current_frame, self, skip_inherited_frame)
      end

      def current_frame=(frame)
        FrameRegistry.set_value_for(:current_frame, self, frame)
        # Invalidate cached builders - they depend on arel_table which
        # depends on current_frame. Without this, stale table references
        # (e.g., "bad_sql/users") survive frame transitions.
        FrameRegistry.set_value_for(:predicate_builder, self, nil)
        FrameRegistry.set_value_for(:table_metadata, self, nil)
      end

      # Per-class, thread-local reframe_values. A relation copies its own
      # reframe_values onto its model here just before building Arel, so that
      # ActiveRecord's JoinDependency (which only receives the base class, not
      # the relation) can read them back while constructing JOINs.
      def reframe_values
        FrameRegistry.value_for(:reframe_values, self, true) || {}
      end

      def reframe_values=(value)
        FrameRegistry.set_value_for(:reframe_values, self, value)
      end

      # Override arel_table to use current_frame's table if set.
      # This ensures that when building JOINs for reframed associations,
      # the framed table (e.g., "deleted/documents") is used instead of the base table (e.g., "documents").
      # This is the KEY to eliminating invasive tree-walking (fix_right_side).
      #
      # When ignoring frames (ignore_frames = true), we must return the base table.
      # Otherwise, if a frame is active when default_scope is evaluated, the scope will cache
      # the framed table name (e.g., "all/users") instead of the base table ("users"),
      # causing table reference pollution.
      def arel_table
        return super if ignore_frames?
        current_frame&.arel_table || super
      end

      # Returns the base Arel::Table, bypassing any current_frame.
      # Always constructs a fresh table from table_name, ignoring frame overrides.
      def unframed_arel_table
        Arel::Table.new(table_name, type_caster: type_caster)
      end

      # Thread-local predicate_builder. Delegates to super but ensures the
      # class-level cache is clean before doing so - AR's @predicate_builder
      # is a ||= cache that gets permanently poisoned if initialized while
      # a frame is active.
      def predicate_builder
        FrameRegistry.value_for(:predicate_builder, self) || begin
          # Clear AR's class-level cache so super builds fresh from current arel_table
          @predicate_builder = nil
          pb = super
          FrameRegistry.set_value_for(:predicate_builder, self, pb)
          pb
        end
      end

      # Thread-local table_metadata, same pattern as predicate_builder.
      def table_metadata
        FrameRegistry.value_for(:table_metadata, self) || begin
          @table_metadata = nil
          tm = super
          FrameRegistry.set_value_for(:table_metadata, self, tm)
          tm
        end
      end

      def const_missing(const_name)
        if (frame = defined_frames[const_name])
          columns
          result = instance_exec(&frame)
          # Reset frame context on base class. Cache invalidation is
          # handled automatically by current_frame= setter.
          base_class.current_frame = nil
          result
        else
          super
        end
      end
    end

    # This class stores the +:current_frame+ and +:ignore_frames+ values
    # for different classes. The registry is stored as a thread local, which is
    # accessed through +FrameRegistry.current+.
    #
    # This class allows you to store and get the frame values on different
    # classes and different types of frames. For example, if you are attempting
    # to get the current_frame for the +Board+ model, then you would use the
    # following code:
    #
    #   registry = ActiveRecord::Framing::FrameRegistry
    #   registry.set_value_for(:current_frame, Board, some_new_frame)
    #
    # Now when you run:
    #
    #   registry.value_for(:current_frame, Board)
    #
    # You will obtain whatever was defined in +some_new_frame+. The #value_for
    # and #set_value_for methods are delegated to the current FrameRegistry
    # object, so the above example code can also be called as:
    #
    #   ActiveRecord::Framing::FrameRegistry.set_value_for(:current_frame,
    #       Board, some_new_frame)
    class FrameRegistry # :nodoc:
      # Per-thread instance, formerly provided by ActiveSupport::PerThreadRegistry
      # (removed in Rails 7.2). Reimplemented here so framing works across the
      # full activerecord 5.1-8.2 range without depending on that helper.
      def self.instance
        Thread.current[:active_record_framing_registry] ||= new
      end

      def self.value_for(frame_type, model, skip_inherited_frame = false)
        instance.value_for(frame_type, model, skip_inherited_frame)
      end

      def self.set_value_for(frame_type, model, value)
        instance.set_value_for(frame_type, model, value)
      end

      VALID_SCOPE_TYPES = [:current_frame, :ignore_frames, :predicate_builder, :table_metadata, :reframe_values].freeze

      attr_accessor :disabled

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = {} }
        @disabled = false
      end

      # Obtains the value for a given +scope_type+ and +model+.
      # Walks up the class hierarchy if skip_inherited_frame is false.
      def value_for(frame_type, model, skip_inherited_frame = false)
        raise_invalid_frame_type!(frame_type)
        return @registry[frame_type][model] if skip_inherited_frame
        # Walk up the hierarchy to ActiveRecord::Base
        # This handles abstract intermediate classes correctly
        while model < ::ActiveRecord::Base
          value = @registry[frame_type][model]
          return value if value
          model = model.superclass
        end
        nil
      end

      # Sets the +value+ for a given +frame_type+ and +model+.
      def set_value_for(frame_type, model, value)
        raise_invalid_frame_type!(frame_type)
        @registry[frame_type][model] = value
      end

      private

        def raise_invalid_frame_type!(frame_type)
          if !VALID_SCOPE_TYPES.include?(frame_type)
            raise ArgumentError, "Invalid frame type '#{frame_type}' sent to the registry. Frame types must be included in VALID_SCOPE_TYPES"
          end
        end
    end
  end
end
