module ActiveRecord
  module Framing
    module JoinDependency
      # table_aliases_for was removed in Rails 7.0+
      # Only define this override if the method exists on the parent
      if ::ActiveRecord::Associations::JoinDependency.method_defined?(:table_aliases_for) ||
         ::ActiveRecord::Associations::JoinDependency.private_method_defined?(:table_aliases_for)

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
            table.left.engine = engine if table.left.respond_to?(:engine=)
          when ::Arel::Table
            table = engine.arel_table
          end
          table
        end
      end
    end
  end
end
