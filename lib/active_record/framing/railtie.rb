require 'rails/railtie'
require 'active_record/framing/core_extension'
require 'active_record/framing/query_methods'
require 'active_record/framing/spawn_methods'
require 'active_record/framing/attribute_methods'
require 'active_record/framing/relation'
require 'active_record/framing/join_dependency'
require 'active_record/framing/inheritance'
require 'active_record/framing/reflection'

module ActiveRecord::Framing
  class Railtie < Rails::Railtie
    initializer 'active_record-framing.load' do |_app|
      ActiveSupport.on_load(:active_record) do
        ::ActiveRecord::Base.prepend(ActiveRecord::Framing)
        ::ActiveRecord::Base.prepend(ActiveRecord::Framing::Inheritance)

        ::ActiveRecord::Reflection.prepend(ActiveRecord::Framing::Reflection)
        ::ActiveRecord::Reflection::MacroReflection.prepend(ActiveRecord::Framing::MacroReflection)

        ::ActiveRecord::Relation.prepend(ActiveRecord::Framing::Relation)
        ::ActiveRecord::Relation.prepend(ActiveRecord::Framing::QueryMethods)
        ::ActiveRecord::Relation.prepend(ActiveRecord::Framing::SpawnMethods)
        ::ActiveRecord::Associations::JoinDependency.prepend(ActiveRecord::Framing::JoinDependency)
      end
    end
  end
end
