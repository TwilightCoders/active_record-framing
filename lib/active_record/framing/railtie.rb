require 'rails/railtie'
require 'active_record/framing/core_extension'
require 'active_record/framing/query_methods'
require 'active_record/framing/spawn_methods'
require 'active_record/framing/attribute_methods'
require 'active_record/framing/relation'
require 'active_record/framing/associations/join_dependency'

module ActiveRecord::Framing
  class Railtie < Rails::Railtie
    initializer 'active_record-framing.load' do |_app|
      ActiveSupport.on_load(:active_record) do
        ::ActiveRecord::Base.include(ActiveRecord::Framing)
        ::ActiveRecord::Relation.prepend(ActiveRecord::Framing::Relation)
        ::ActiveRecord::Relation.include(ActiveRecord::Framing::QueryMethods)
        ::ActiveRecord::Relation.prepend(ActiveRecord::Framing::SpawnMethods)
        ::ActiveRecord::Associations::JoinDependency.prepend(ActiveRecord::Framing::Associations::JoinDependency)
      end
    end
  end
end
