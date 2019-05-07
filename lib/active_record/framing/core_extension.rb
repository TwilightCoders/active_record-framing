# frozen_string_literal: true

require "active_support/per_thread_registry"

module ActiveRecord
  module Framing
    extend ActiveSupport::Concern

    included do
      include Default
      include Named
      include AttributeMethods
    end

    module ClassMethods # :nodoc:
      def current_frame
        FrameRegistry.value_for(:current_frame, self)
      end

      def current_frame=(frame)
        FrameRegistry.set_value_for(:current_frame, self, frame)
      end

      def with_deleted_at
      end

      # Collects attributes from frames that should be applied when creating
      # an AR instance for the particular class this is called on.
      def frame_attributes
        all.frame_for_create
      end

      # Are there attributes associated with this frame?
      def frame_attributes?
        current_frame
      end
    end

    def populate_with_current_frame_attributes # :nodoc:
      return unless self.class.frame_attributes?

      attributes = self.class.frame_attributes
      _assign_attributes(attributes) if attributes.any?
    end

    def initialize_internals_callback # :nodoc:
      super
      populate_with_current_frame_attributes
    end

    # This class stores the +:current_frame+ and +:ignore_default_frame+ values
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

      VALID_SCOPE_TYPES = [:current_frame, :ignore_default_frame]

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = {} }
      end

      # Obtains the value for a given +frame_type+ and +model+.
      def value_for(frame_type, model)
        raise_invalid_frame_type!(frame_type)
        return @registry[frame_type][model.name]
      end

      # def value_for(frame_type, model, skip_inherited_frame = false)
      #   raise_invalid_frame_type!(frame_type)
      #   return @registry[frame_type][model.name] if skip_inherited_frame
      #   klass = model
      #   base = model.base_class
      #   while klass <= base
      #     value = @registry[frame_type][klass.name]
      #     return value if value
      #     klass = klass.superclass
      #   end
      # end

      # Sets the +value+ for a given +frame_type+ and +model+.
      def set_value_for(frame_type, model, value)
        raise_invalid_frame_type!(frame_type)
        @registry[frame_type][model.name] = value
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