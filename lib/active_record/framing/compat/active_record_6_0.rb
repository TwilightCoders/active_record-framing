module ActiveRecord
  module Framing
    module QueryMethods
      FROZEN_EMPTY_HASH = {}.freeze

      # Note: The @values key is :frames (plural) to avoid conflicts with the frame() method,
      # but the accessor is frame_values (singular) to match Rails naming conventions.
      def frame_values
        @values.fetch(:frames, FROZEN_EMPTY_HASH)
      end

      def frame_values=(value)
        assert_mutability!
        @values[:frames] = value
      end

      def reframe_values
        @values.fetch(:reframe, FROZEN_EMPTY_HASH)
      end

      def reframe_values=(value)
        assert_mutability!
        @values[:reframe] = value
      end

      # Bind values accessor for frame CTEs
      def frame_bind_values
        @values.fetch(:frame_bind, FROZEN_EMPTY_HASH)
      end

      def frame_bind_values=(value)
        assert_mutability!
        @values[:frame_bind] = value
      end
    end
  end
end
