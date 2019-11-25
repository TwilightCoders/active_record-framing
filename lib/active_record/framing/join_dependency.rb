module ActiveRecord
  module Framing
    module JoinDependency

      def table_aliases_for(parent, node)
        super.tap do |list|
          list.zip(node.reflection.chain).each do |aliaz, reflection|
            fix_table_engine(aliaz, reflection.klass)
          end
        end
      end

      def fix_table_engine(table, engine)
        case table
        when ::Arel::Nodes::TableAlias
          table.left.instance_variable_set(:@engine, engine) if table.left.engine == ::ActiveRecord::Base
        end
        table.instance_variable_set(:@engine, engine) if table.engine == ::ActiveRecord::Base
      end
    end
  end
end
