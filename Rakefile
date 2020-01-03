# === boot ===

begin
  require "bundler/setup"
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

# === application ===

require "active_record/railtie"
Bundler.require :default, Rails.env

require "combustion"
Combustion.path = 'spec/support/rails'

# === Rakefile ===

task :console do
  Combustion.initialize! :active_record
  ActiveRecord::Base.connection # Establishes a connection
  require 'rails/commands'
end

require "rspec/core/rake_task"

# This gives us all the db:* and other rails rakes
Combustion::Application.load_tasks

task(:default).clear
task(:spec).clear

RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
end

task default: [:spec]
