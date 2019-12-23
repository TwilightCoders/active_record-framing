module ActiveRecord
  module Framing
    module JoinDependency
      def table_aliases_for(parent, node)
        super.tap do |list|
          list.zip(node.reflection.chain).each do |aliaz, reflection|
            engine = @join_root.base_klass.reframe_values.fetch(reflection.name) { reflection }.klass
            fix_table_engine(aliaz, engine)
          end
        end
      end

      def fix_table_engine(table, engine)
        case table
        when ::Arel::Nodes::TableAlias
          table.left.engine = engine # if table.left.engine == ::ActiveRecord::Base
          table.left.name = engine.table_name
        else
          table.engine = engine # if table.engine == ::ActiveRecord::Base
          table.name = engine.table_name
        end
        # binding.pry if table.name == "users"
      end
    end
  end
end
