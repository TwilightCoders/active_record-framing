# frozen_string_literal: true

require "active_support/per_thread_registry"

module ActiveRecord
  module Framing

    def self.prepended(subclass)
      subclass.singleton_class.class_eval do
        alias_method :unframed_all, :all
      end

      subclass.include Default
      subclass.extend Named
      subclass.include AttributeMethods
      subclass.extend ClassMethods
    end

    module ClassMethods # :nodoc:
      def current_frame
        FrameRegistry.value_for(:current_frame, self)
      end

      def current_frame=(frame)
        FrameRegistry.set_value_for(:current_frame, self, frame)
      end
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
