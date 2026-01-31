module ActiveRecord
  module Framing
    module QueryMethods
      FROZEN_EMPTY_HASH = {}.freeze
      FROZEN_EMPTY_FRAME_CLAUSE = ActiveRecord::Framing::FrameClause.new.freeze

      # Define frame_clause accessor (following the WhereClause pattern)
      # The @values key is :frame to match the clause naming convention
      def frame_clause
        @values.fetch(:frame, FROZEN_EMPTY_FRAME_CLAUSE)
      end

      def frame_clause=(value)
        assert_mutability!
        @values[:frame] = value
      end

      def reframe_values
        @values.fetch(:reframe, FROZEN_EMPTY_HASH)
      end

      def reframe_values=(value)
        assert_mutability!
        @values[:reframe] = value
      end
    end
  end
end
