# frozen_string_literal: true

module ActiveRecord
  module Framing
    # FrameClause stores frame Relations, similar to how WhereClause stores predicates.
    # This allows ActiveRecord's built-in Merger to properly propagate frame Relations
    # through the relation chain.
    #
    # IMPORTANT: Unlike WHERE clause subqueries (which extract binds via PredicateBuilder),
    # CTEs added via ar.with() don't have automatic bind extraction. We must cache
    # bound_attributes from frame Relations BEFORE compiling to Arel, because once
    # compiled, the Arel tree has BindParam nodes but no connection to actual bind values.
    class FrameClause
      attr_reader :frames

      def initialize(frames = {})
        # frames is a hash of {table_name => Relation}
        @frames = frames.freeze
        # Binds cached from frame Relations (populated by binds method)
        @cached_binds = nil
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

        FrameClause.new(frames.merge(other.frames))
      end

      # Combine two FrameClauses (used by spawn)
      def +(other)
        merge(other)
      end

      # Get bind values from frame Relations
      # MUST be called BEFORE to_arel_ctes to cache binds before Relations are compiled
      # Returns empty array if binds were substituted into SQL (prepared_statements=false)
      def binds
        return [] if @binds_substituted
        @cached_binds ||= frames.values.flat_map(&:bound_attributes)
      end

      # Compile frames to Arel CTE nodes
      # When prepared_statements=false, substitutes bind values into SQL instead of
      # using BindParam nodes, because ActiveRecord discards binds in that mode.
      def to_arel_ctes
        # Detect prepared_statements setting from first relation
        first_relation = frames.values.first
        use_prepared_statements = first_relation ? first_relation.klass.connection.prepared_statements : true

        @binds_substituted = !use_prepared_statements

        frames.map do |table_name, relation|
          cte_table = relation.arel_table

          if use_prepared_statements
            # Standard mode: Arel tree with BindParam nodes
            cte_arel = relation.arel
          else
            # Prepared statements disabled: substitute binds into SQL
            cte_sql = relation.to_sql
            cte_arel = Arel::Nodes::SqlLiteral.new("(#{cte_sql})")
          end

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
