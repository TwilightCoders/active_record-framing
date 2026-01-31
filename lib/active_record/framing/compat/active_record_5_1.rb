module ActiveRecord
  module Framing
    module QueryMethods
      # Note: The @values key is :frames (plural) to avoid conflicts with the frame() method,
      # but the accessor is frame_values (singular) to match Rails naming conventions.

      define_method(:frame_values) do
        get_value(:frames)
      end

      define_method(:frame_values=) do |value|
        set_value(:frames, value)
      end

      define_method(:reframe_values) do
        get_value(:reframe)
      end

      define_method(:reframe_values=) do |value|
        set_value(:reframe, value)
      end

      ::ActiveRecord::QueryMethods::DEFAULT_VALUES[:frames] = ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
      ::ActiveRecord::QueryMethods::DEFAULT_VALUES[:reframe] = ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
    end
  end
end
