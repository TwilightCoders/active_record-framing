module ActiveRecord
  module Framing
    class ModelProxy < SimpleDelegator

      def initialize(klass, table)
        @table = table
        super(klass)
      end

      def unscoped
        super.tap do |rel|
          base_table = __getobj__.arel_table
          rel.instance_variable_set(:@table, base_table)
        end
      end

      def arel_attribute(column_name, table = arel_table)
        super
      end

      def scope_for_association(scope = __getobj__.relation)
        super
      end

      def table=(value)
        @table = value
      end

      def table_name
        @table.name
      end

      def reframe_values
        @reframe_values ||= {}
      end

      def reframe_values=(value)
        @reframe_values = value
      end

      def arel_table
        @table
      end

      # Ensure ModelProxy behaves like a Class for type-checking
      def ===(other)
        __getobj__ === other
      end

      # Delegate class identity checks to the wrapped class
      def name
        __getobj__.name
      end
    end
  end
end
