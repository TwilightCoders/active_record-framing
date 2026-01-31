require 'bundler/setup'
require 'combustion'

Combustion.path = 'spec/support/rails'
Combustion.initialize! :active_record
require 'active_record-framing'

# Load the User model
require_relative 'spec/support/rails/app/models/user'

# Patch calculations to see what binds are passed
ActiveRecord::Relation::Calculations.module_eval do
  alias_method :orig_execute_simple_calculation, :execute_simple_calculation

  def execute_simple_calculation(operation, column_name, distinct)
    puts "\n=== EXECUTE_SIMPLE_CALCULATION DEBUG ==="
    puts "self.class: #{self.class}"
    puts "self.frame_clause.empty?: #{frame_clause.empty?}"
    puts "self.bound_attributes.length: #{bound_attributes.length}"
    puts "self.bound_attributes: #{bound_attributes.inspect}"

    # Call original with debug
    result = orig_execute_simple_calculation(operation, column_name, distinct)
    puts "=== END DEBUG ===\n"
    result
  end
end

# Patch select_all to see what it receives
ActiveRecord::ConnectionAdapters::AbstractAdapter.module_eval do
  alias_method :orig_select_all, :select_all

  def select_all(arel, name = nil, binds = [], preparable = nil)
    if arel.respond_to?(:to_sql) && arel.to_sql.include?('WITH')
      puts "\n=== SELECT_ALL RECEIVED ==="
      puts "arel class: #{arel.class}"
      puts "binds class: #{binds.class}"
      puts "binds.length: #{binds.length}"
      puts "binds: #{binds.inspect}"
      puts "=== END SELECT_ALL ===\n"
    end
    orig_select_all(arel, name, binds, preparable)
  end
end

puts "\n*** Calling User.count ***"
count = User.count
puts "Result: #{count}"
