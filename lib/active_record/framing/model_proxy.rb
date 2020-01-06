module ActiveRecord
  module Framing
    class ModelProxy < SimpleDelegator

      def initialize(klass, table)
        @table = table
        super(klass)
      end

      def unscoped
        super.tap do |rel|
          rel.instance_variable_set(:@table, @table)
        end
      end

      # NOTE: Arel 8.x / Rails 5.1 compatibility
      # Method exists on AR::Model, but default value for table attribute
      # is gathered in the wrong context without this proxy override
      def arel_attribute(column_name, table = arel_table)
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

      def send(*args)
        __getobj__.send(*args)
      end

      def arel_table
        @table
      end

      # Might not need this
      # def is_a?(obj)
      #   __getobj__.is_a?(obj)
      # end
    end
  end
end
