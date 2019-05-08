ENV['RAILS_ENV'] = 'test'

require 'database_cleaner'
require 'combustion'
require 'pry'

require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

Combustion.path = 'spec/support/rails'
Combustion.initialize! :active_record

require 'active_record/framing/railtie' if defined?(Rails::Railtie)

# ActiveRecord::Base.logger = Logger.new(STDOUT)

RSpec.configure do |config|
  config.order = 'random'

  # Configure the DatabaseCleaner
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

RSpec::Matchers.define :eq_sql do |expected_sql|
  match do |actual_sql|
    actual_sql == expected_sql
  end

  failure_message do |actual_sql|
    "expected:\n#{expected_sql.indent(2)}\nto equal:\n#{actual_sql.indent(2)}"
  end
end

RSpec::Matchers.define :match_sql do |expected_sql|
  expected_sql.squish!.gsub!(/([\(\)\/])/, '\\\\\1')

  match do |actual_sql|
    actual_sql.match(Regexp.new(expected_sql))
  end

  failure_message do |actual_sql|
    "expected:\n#{expected_sql.indent(2)}\nto match:\n#{actual_sql.indent(2)}"
  end
end
