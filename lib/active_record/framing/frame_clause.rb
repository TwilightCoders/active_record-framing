# frozen_string_literal: true

module ActiveRecord
  module Framing
    # FrameClause stores frame Relations and their bind values together,
    # similar to how WhereClause stores predicates and binds.
    # This allows ActiveRecord's built-in Merger to properly propagate
    # both the frame Relations and their bind values through the relation chain.
    class FrameClause
      attr_reader :frames

      def initialize(frames = {}, cached_binds = nil, prepared_statements = nil)
        # frames is a hash of {table_name => Relation}
        @frames = frames.freeze
        # Cache the binds to avoid recompiling after to_arel_ctes is called
        @cached_binds = cached_binds
        # Track if prepared statements are enabled
        @prepared_statements = prepared_statements
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
        # Preserve prepared_statements setting
        ps = @prepared_statements.nil? ? other.instance_variable_get(:@prepared_statements) : @prepared_statements
        FrameClause.new(frames.merge(other.frames), combined_binds, ps)
      end

      # Combine two FrameClauses (used by spawn)
      def +(other)
        merge(other)
      end

      # Get all bound_attributes from the frame Relations
      # IMPORTANT: Cache this before calling to_arel_ctes because
      # compiling relations consumes their bound_attributes
      # When prepared_statements are disabled, return empty array because
      # binds are substituted into SQL instead
      def binds
        # Check if we know prepared_statements status
        if @prepared_statements == false
          # Binds already substituted into SQL, don't return them
          []
        else
          # Cache and return binds for prepared statements
          @cached_binds ||= frames.values.flat_map(&:bound_attributes)
        end
      end

      # Compile frames to Arel CTE nodes
      # IMPORTANT: This should only be called once, right before query execution
      # After this is called, the Relations' bound_attributes will be consumed
      def to_arel_ctes
        # Detect prepared_statements setting from first relation
        first_relation = frames.values.first
        use_prepared_statements = first_relation ? first_relation.klass.connection.prepared_statements : true

        # Store for binds method
        @prepared_statements = use_prepared_statements

        frames.map do |table_name, relation|
          # Get the arel_table from the relation
          cte_table = relation.arel_table

          # Check if prepared statements are disabled
          # When disabled, we need to substitute bind values into SQL
          if use_prepared_statements == false
            # Convert relation to SQL with bind substitution
            cte_sql = relation.to_sql
            # Create Arel node from SQL literal
            cte_arel = Arel::Nodes::SqlLiteral.new("(#{cte_sql})")
          else
            # With prepared statements enabled, use standard Arel compilation
            cte_arel = relation.arel
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
