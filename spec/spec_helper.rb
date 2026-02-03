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

# Version-aware spec helpers
module VersionHelpers
  def rails_version
    @rails_version ||= Gem::Version.new(ActiveRecord.version.to_s)
  end

  def skip_unless_rails(requirement)
    required = Gem::Requirement.new(requirement)
    unless required.satisfied_by?(rails_version)
      skip("Requires Rails #{requirement}, running #{rails_version}")
    end
  end

  def pending_unless_rails(requirement, message = nil)
    required = Gem::Requirement.new(requirement)
    unless required.satisfied_by?(rails_version)
      pending(message || "Requires Rails #{requirement}, running #{rails_version}")
    end
  end
end

RSpec.configure do |config|
  config.include VersionHelpers
  config.order = 'random'

  config.example_status_persistence_file_path = 'spec/results.txt'

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  # Clean up any leftover current_frame settings BEFORE each test
  # This prevents test pollution from frames set by previous tests
  config.before(:each) do
    # Get all loaded AR models (including dynamically created ones like SuperAdmin)
    models = ObjectSpace.each_object(Class).select { |klass| klass < ActiveRecord::Base }
    models.each do |klass|
      klass.current_frame = nil rescue nil
      ActiveRecord::Framing::FrameRegistry.set_value_for(:ignore_frames, klass.base_class, false) rescue nil
    end
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

# RegexMarker: Embeds regex patterns in SQL heredocs
# Usage: expect(sql).to match_sql(<<~SQL)
#          SELECT * FROM users WHERE #{rx('.*?')}
#        SQL
class RegexMarker
  # Class variable to prevent GC of marker objects
  @@markers = {}

  attr_reader :regex

  def initialize(pattern)
    @regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
    # Store reference to prevent garbage collection
    @@markers[object_id] = self
  end

  def self.lookup(object_id)
    @@markers[object_id]
  end

  def self.clear_markers
    @@markers.clear
  end

  def to_s
    "___REGEX_#{object_id}___"
  end
end

# Helper to create regex markers
def rx(pattern)
  RegexMarker.new(pattern)
end

RSpec::Matchers.define :match_sql do |expected_sql|
  # Hybrid approach: Literal SQL with embedded regex patterns
  # - Most SQL is literal (readable, maintainable)
  # - Use rx('pattern') to embed regex where needed for flexibility
  # - Auto-escapes all special chars except embedded patterns

  actual_normalized = nil
  template = expected_sql.squish

  # Extract all RegexMarker objects from the template string
  # They appear as ___REGEX_<object_id>___ after to_s conversion
  regex_markers = {}
  template.scan(/___REGEX_(\d+)___/).each do |match|
    object_id = match[0].to_i
    marker = ObjectSpace._id2ref(object_id)
    if marker.is_a?(RegexMarker)
      regex_markers[object_id] = marker.regex
    end
  end

  # Split template into parts: literal SQL and regex markers
  parts = template.split(/(___REGEX_\d+___)/)

  # Process each part
  escaped_parts = parts.map do |part|
    if part =~ /\A___REGEX_(\d+)___\z/
      # This is a regex marker - use the pattern as-is
      object_id = $1.to_i
      regex_markers[object_id].source
    else
      # This is literal SQL - escape special regex chars
      Regexp.escape(part)
    end
  end

  pattern = escaped_parts.join
  expected_regex = Regexp.new(pattern)

  match do |actual_sql|
    actual_normalized = actual_sql.squish
    actual_normalized.match(expected_regex)
  end

  failure_message do |actual_sql|
    "expected:\n  #{actual_normalized}\nto match pattern:\n  #{pattern}\nfrom template:\n  #{expected_sql.squish}"
  end
end
