# Shim for activerecord 6.0 through 8.x. The @values-hash storage and the
# mutability guard are stable across this range, except that the guard was
# renamed assert_mutability! -> assert_modifiable! (Rails 7.2), so we call
# whichever the running version provides.
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
        assert_framing_mutability!
        @values[:frame] = value
      end

      def reframe_values
        @values.fetch(:reframe, FROZEN_EMPTY_HASH)
      end

      def reframe_values=(value)
        assert_framing_mutability!
        @values[:reframe] = value
      end

      private

      def assert_framing_mutability!
        respond_to?(:assert_modifiable!, true) ? assert_modifiable! : assert_mutability!
      end
    end
  end
end
