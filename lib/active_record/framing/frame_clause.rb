# frozen_string_literal: true

module ActiveRecord
  module Framing
    # FrameClause stores frame Relations and their bind values together,
    # similar to how WhereClause stores predicates and binds.
    # This allows ActiveRecord's built-in Merger to properly propagate
    # both the frame Relations and their bind values through the relation chain.
    class FrameClause
      attr_reader :frames

      def initialize(frames = {}, cached_binds = nil)
        # frames is a hash of {arel_table => Relation}
        # The arel_table is the CTE's table (e.g., name "all/users" for User::All)
        # The Relation is the CTE definition (the SQL inside the WITH clause)
        @frames = frames.freeze
        # Cache the binds to avoid recompiling after to_arel_ctes is called
        @cached_binds = cached_binds
      end

      def empty?
        frames.empty?
      end

      def any?
        !empty?
      end

      # Merge another FrameClause into this one
      def merge(other)
        return self if other.empty?
        return other if empty?

        # Combine binds from both clauses
        combined_binds = binds + other.binds
        FrameClause.new(frames.merge(other.frames), combined_binds)
      end

      # Combine two FrameClauses (used by spawn)
      def +(other)
        merge(other)
      end

      # Get all bound_attributes from the frame Relations
      # IMPORTANT: Cache this before calling to_arel_ctes because
      # compiling relations consumes their bound_attributes
      def binds
        @cached_binds ||= frames.values.flat_map(&:bound_attributes)
      end

      # Compile frames to Arel CTE nodes
      # IMPORTANT: This should only be called once, right before query execution
      # After this is called, the Relations' bound_attributes will be consumed
      def to_arel_ctes
        frames.map do |cte_table, relation|
          # The hash key is the Arel::Table with the correct CTE name
          # For named frames like User::All, cte_table.name is "all/users"
          # The relation is the CTE definition (has table="users")

          if relation.connection.prepared_statements
            # Use Arel AST with $1 placeholders
            cte_arel = relation.arel
          else
            # For prepared_statements=false, we need to substitute binds inline
            # Create a relation without frames to prevent nested CTEs
            stripped = relation.spawn
            stripped.frame_clause = FrameClause.new({})
            # Compile to SQL with binds substituted inline
            sql = stripped.to_sql
            cte_arel = Arel::Nodes::SqlLiteral.new("(#{sql})")
          end

          # Create the CTE node
          Arel::Nodes::As.new(cte_table, cte_arel)
        end
      end

      def ==(other)
        other.is_a?(FrameClause) && frames == other.frames
      end

      def hash
        frames.hash
      end
    end
  end
end
