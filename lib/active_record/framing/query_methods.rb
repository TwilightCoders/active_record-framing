require 'active_record/relation'

module ActiveRecord
  module Framing
    module QueryMethods

      def frame(value)
        spawn.frame!(frame_cte_for(value))
      end

      def frame!(frame_relations)
        # frame_relations is a hash of {arel_table => Relation}
        # Create a new FrameClause and merge it with the existing one
        new_clause = FrameClause.new(frame_relations)
        self.frame_clause = frame_clause.merge(new_clause)
        self
      end

      def frame_cte_for(value)
        value = value.all if (value.is_a?(Class) && value < ::ActiveRecord::Base)

        cte = \
          case value
          when ::ActiveRecord::Relation
            # Extract the frames hash from the FrameClause
            value.frame_clause.frames
          when Arel::Nodes::As
            # Use the CTE's arel_table (left side of AS) as the key
            {value.left => value}
          when String
            # For string values, use arel_table as key
            {arel_table => value}
          when Hash
            value
          else
            {}
          end
      end

      def reframe(*args)
        spawn.reframe!(*args)
      end

      # TODO: Consistent keys class: symbol, string, Arel::Table
      def reframe!(*args)
        args.flatten!
        # TODO: Convert array (if present) to nil hash {value => nil}
        # and merge with hash (if present) as second arg
        self.reframe_values = self.reframe_values.merge(args.first)
        self
      end
    end
  end
end
