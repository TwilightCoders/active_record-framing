module ActiveRecord
  module Framing
    module QueryMethods
      # Define frame_clause accessor (following the WhereClause pattern)
      # The @values key is :frame to match the clause naming convention

      define_method(:frame_clause) do
        get_value(:frame) || ActiveRecord::Framing::FrameClause.new
      end

      define_method(:frame_clause=) do |value|
        set_value(:frame, value)
      end

      define_method(:reframe_values) do
        get_value(:reframe)
      end

      define_method(:reframe_values=) do |value|
        set_value(:reframe, value)
      end

      ::ActiveRecord::QueryMethods::DEFAULT_VALUES[:frame] = ActiveRecord::Framing::FrameClause.new.freeze
      ::ActiveRecord::QueryMethods::DEFAULT_VALUES[:reframe] = ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
    end
  end
end
