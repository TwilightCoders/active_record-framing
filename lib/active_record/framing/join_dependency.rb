module ActiveRecord
  module Framing
    module JoinDependency
      def table_aliases_for(parent, node)
        super.tap do |list|
          list.zip(node.reflection.chain).each_with_index do |(table, reflection), i|
            engine = @join_root.base_klass.reframe_values.fetch(reflection.name) { reflection }.klass
            list[i] = fix_table_engine(table, engine)
          end
        end
      end

      def fix_table_engine(table, engine)
        case table
        when ::Arel::Nodes::TableAlias
          table.left.engine = engine
        when ::Arel::Table
          table = engine.arel_table
        else
          warn "no good"
        end
        table
      end
    end
  end
end
