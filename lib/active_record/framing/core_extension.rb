# frozen_string_literal: true

require "active_record/framing/default"
require "active_record/framing/named"

module ActiveRecord
  module Framing

    def self.prepended(subclass)
      subclass.singleton_class.class_eval do
        alias_method :unframed_all, :all
        alias_method :unframed_scope_for_association, :scope_for_association if subclass.respond_to?(:scope_for_association)
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

    module ClassMethods
      def current_frame(skip_inherited_frame: false)
        FrameRegistry.value_for(:current_frame, self, skip_inherited_frame)
      end

      def current_frame=(frame)
        FrameRegistry.set_value_for(:current_frame, self, frame)
      end

      def arel_table
        return super if ignore_frames?
        current_frame&.arel_table || super
      end

      def unframed_arel_table
        if respond_to?(:type_caster, true)
          Arel::Table.new(table_name, type_caster: send(:type_caster))
        else
          Arel::Table.new(table_name)
        end
      end

      def predicate_builder
        FrameRegistry.value_for(:predicate_builder, self) || begin
          pb = super
          FrameRegistry.set_value_for(:predicate_builder, self, pb)
          pb
        end
      end

      def table_metadata
        FrameRegistry.value_for(:table_metadata, self) || begin
          tm = super
          FrameRegistry.set_value_for(:table_metadata, self, tm)
          tm
        end
      end

      def const_missing(const_name)
        if frames.key?(const_name)
          columns
          result = frames[const_name].call
          # Clean up thread-local state after frame construction
          base = base_class
          base.current_frame = nil
          FrameRegistry.set_value_for(:predicate_builder, base, nil)
          FrameRegistry.set_value_for(:table_metadata, base, nil)
          result
        else
          super
        end
      end
    end

    # Thread-local registry for frame state.
    # Each thread gets its own isolated instance via Thread.current.
    class FrameRegistry
      VALID_SCOPE_TYPES = [:current_frame, :ignore_frames, :predicate_builder, :table_metadata].freeze
      THREAD_KEY = :active_record_framing_registry

      attr_accessor :disabled

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = {} }
        @disabled = false
      end

      def self.instance
        Thread.current[THREAD_KEY] ||= new
      end

      def self.value_for(frame_type, model, skip_inherited_frame = false)
        instance.value_for(frame_type, model, skip_inherited_frame)
      end

      def self.set_value_for(frame_type, model, value)
        instance.set_value_for(frame_type, model, value)
      end

      def value_for(frame_type, model, skip_inherited_frame = false)
        validate_frame_type!(frame_type)
        return @registry[frame_type][model] if skip_inherited_frame

        klass = model
        while klass < ::ActiveRecord::Base
          val = @registry[frame_type][klass]
          return val if val
          klass = klass.superclass
        end
        nil
      end

      def set_value_for(frame_type, model, value)
        validate_frame_type!(frame_type)
        @registry[frame_type][model] = value
      end

      private

      def validate_frame_type!(frame_type)
        return if VALID_SCOPE_TYPES.include?(frame_type)
        raise ArgumentError, "Invalid frame type '#{frame_type}'. Valid: #{VALID_SCOPE_TYPES.join(', ')}"
      end
    end
  end
end
