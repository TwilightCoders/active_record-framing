require 'active_record/framing/compat/arel'

case ::ActiveRecord.version
when Gem::Requirement.new('~> 5.0.0') # 5.0.x
  require 'active_record/framing/compat/active_record_5_0'
when Gem::Requirement.new('~> 5.1') # 5.1+
  require 'active_record/framing/compat/active_record_5_1'
when Gem::Requirement.new('>= 6.0') # 6.0+
  require 'active_record/framing/compat/active_record_6_0'
end
