ENV['RAILS_ENV'] = 'test'

require 'database_cleaner'
require 'combustion'
require 'pry'
require 'colorize'

require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

Combustion.path = 'spec/support/rails'
Combustion.initialize! :active_record

require 'active_record/framing/railtie' if defined?(Rails::Railtie)

def log_sql
  orig, ActiveRecord::Base.logger = ActiveRecord::Base.logger, Logger.new(STDOUT)
  yield if block_given?
ensure
  ActiveRecord::Base.logger = orig
end

RSpec.configure do |config|
  config.order = 'random'

  config.example_status_persistence_file_path = 'spec/results.txt'

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
  expected_sql.squish!
  expected_sql.gsub!(/((?<!\\)[\.\*\\\/\(\)])/, '\\\\\1') # Escape all the special characters that are not already escaped
  expected_sql.gsub!(/(\\\\([\(\)]))/, '\2') # "Unescape" the special characters that are already escaped

  expexted_regex = Regexp.new(expected_sql)
  match do |actual_sql|
    actual_sql.match(expexted_regex)
  end

  failure_message do |actual_sql|
    "expected:\n#{actual_sql.indent(2)}\nto match:\n#{expected_sql.indent(2)}"
  end
end
