module ActiveRecord
  module Framing
    module SpawnMethods

      def merge!(other) # :nodoc:
        super.tap do |rel|
          # Use the FrameClause merge method to properly combine clauses
          rel.frame_clause = rel.frame_clause.merge(other.frame_clause)
        end
      end

    end
  end
end
