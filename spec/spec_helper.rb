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
