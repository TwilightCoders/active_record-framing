module ActiveRecord
  module Framing
    module QueryMethods
      # Define frame_clause accessor (following the WhereClause pattern)
      # The @values key is :frame to match the clause naming convention

      define_method(:frame_clause) do
        @values[:frame] || ActiveRecord::Framing::FrameClause.new
      end

      define_method(:frame_clause=) do |value|
        assert_mutability!
        @values[:frame] = value
      end

      # Keep reframe as a simple hash for now
      define_method(:reframe_values) do
        @values[:reframe] || ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
      end

      define_method(:reframe_values=) do |values|
        assert_mutability!
        @values[:reframe] = values
      end
    end
  end
end

