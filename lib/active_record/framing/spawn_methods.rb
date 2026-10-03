module ActiveRecord
  module Framing
    module SpawnMethods

      def merge!(other) # :nodoc:
        super.tap do |rel|
          # Use the FrameClause merge method to properly combine clauses
          rel.frame_clause = rel.frame_clause.merge(other.frame_clause)
        end
      end

      private

        # ActiveRecord 6.0 builds #except/#only results with Relation.create,
        # which resets the table to the model's; keep the framed table (6.1+
        # spawns, which already does).
        def relation_with(values)
          super.tap do |rel|
            rel.table = table unless rel.table == table
          end
        end

    end
  end
end
