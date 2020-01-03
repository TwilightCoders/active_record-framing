require_relative 'lib/active_record/framing/version'

Gem::Specification.new do |spec|
  spec.name          = "active_record-framing"
  spec.version       = ActiveRecord::Framing::VERSION
  spec.authors       = ['Dale Stevens']
  spec.email         = ['dale@twilightcoders.net']

  spec.summary       = %q{Provides larger level scopes (frames) through the use of common table expressions.}
  spec.description   = %q{Allows for larger level scoping (framing) that affect complicated queries more holistically}
  spec.homepage      = "https://github.com/TwilightCoders/active_record-framing"
  spec.license       = "MIT"

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.files         = Dir['CHANGELOG.md', 'README.md', 'LICENSE', 'lib/**/*']
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  rails_versions = '>= 4.2'
  spec.required_ruby_version = '>= 2.3'

  spec.add_runtime_dependency 'activerecord', rails_versions

  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'combustion'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'pry-rails'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'database_cleaner'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'colorize'

end
