module ActiveRecord
  module Framing
    module QueryMethods
      # Note: The @values key is :frames (plural) to avoid conflicts with the frame() method,
      # but the accessor is frame_values (singular) to match Rails naming conventions.

      define_method(:frame_values) do
        @values[:frames] || ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
      end

      define_method(:frame_values=) do |values|
        assert_mutability!
        @values[:frames] = values
      end

      define_method(:reframe_values) do
        @values[:reframe] || ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
      end

      define_method(:reframe_values=) do |values|
        assert_mutability!
        @values[:reframe] = values
      end

      # Bind values accessor for frame CTEs
      define_method(:frame_bind_values) do
        @values[:frame_bind] || ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
      end

      define_method(:frame_bind_values=) do |values|
        assert_mutability!
        @values[:frame_bind] = values
      end
    end
  end
end

