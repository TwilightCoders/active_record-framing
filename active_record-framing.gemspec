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

  rails_versions = ['>= 4.2', '< 6']
  spec.required_ruby_version = '>= 2.3'

  spec.add_runtime_dependency 'activerecord', rails_versions

  spec.add_development_dependency 'pg', '~> 0'
  spec.add_development_dependency 'pry-byebug', '~> 3'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'combustion', '~> 0.7'

end
