# frozen_string_literal: true

require "active_support/per_thread_registry"
require "active_record/framing/default"
require "active_record/framing/named"
# require "active_record/framing/associations"

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
      # subclass.extend Associations
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

    class Foo

      def self.whatever
        @whatever
      end
    end

    module ClassMethods # :nodoc:
      def current_frame(skip_inherited_frame: false)
        FrameRegistry.value_for(:current_frame, self, skip_inherited_frame)
      end

      def current_frame=(frame)
        FrameRegistry.set_value_for(:current_frame, self, frame)
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
      # Works for both Models and ModelProxy (through SimpleDelegator).
      def unframed_arel_table
        Arel::Table.new(table_name, type_caster: type_caster)
      end

      def const_missing(const_name)
        case const_name
        when *frames.keys
          columns
          result = frames[const_name].call
          # Clear all scope/predicate caches to prevent table name pollution
          # During frame building, these may be compiled with a polluted ModelProxy table
          base = base_class
          base.instance_variable_set(:@default_scopes, nil)
          base.instance_variable_set(:@default_scope, nil)
          base.instance_variable_set(:@predicate_builder, nil)
          base.instance_variable_set(:@table_metadata, nil)
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
      extend ActiveSupport::PerThreadRegistry

      VALID_SCOPE_TYPES = [:current_frame, :ignore_frames]

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
