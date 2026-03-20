# Arel::Table engine accessor compatibility
#
# Provides a uniform way to get the model class from an Arel::Table,
# regardless of how Arel stores it internally across versions.

module ActiveRecord
  module Framing
    module ArelCompat
      # Get the AR model class from an Arel::Table
      def self.engine_for(arel_table)
        if arel_table.instance_variable_defined?(:@klass)
          # Rails 7.0+: stored directly as @klass
          arel_table.instance_variable_get(:@klass)
        elsif arel_table.respond_to?(:engine)
          # Rails 5.x-6.x: stored as engine
          arel_table.engine
        elsif arel_table.respond_to?(:type_caster, true)
          tc = arel_table.send(:type_caster)
          tc.respond_to?(:send) ? (tc.send(:types) rescue nil) : nil
        end
      end
    end
  end
end

# Ensure Arel::Table#clone preserves the name for CTE table creation
unless Arel::Table.method_defined?(:name=)
  Arel::Table.class_eval do
    attr_writer :name
  end
end
