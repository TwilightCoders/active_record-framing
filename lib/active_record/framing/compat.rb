require 'active_record/framing/compat/arel'

ar_version = ActiveRecord.version

case ar_version
when Gem::Requirement.new('~> 5.0.0')
  require 'active_record/framing/compat/active_record_5_0'
when Gem::Requirement.new('~> 5.1')
  # 5.1.x and 5.2.x — both use get_value/set_value
  require 'active_record/framing/compat/active_record_5_1'
when Gem::Requirement.new('>= 6.0')
  # 6.0+ through 8.x — uses @values hash directly
  require 'active_record/framing/compat/active_record_6_0'
else
  warn "[active_record-framing] Untested Rails version #{ar_version}. Attempting 6.0+ compat."
  require 'active_record/framing/compat/active_record_6_0'
end
