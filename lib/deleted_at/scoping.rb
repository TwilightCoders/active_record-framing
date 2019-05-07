module DeletedAt
  module Scoping

    module ClassMethods
      def current_scope(skip_inherited_scope = false)
        ScopeRegistry.value_for(:current_scope, self, skip_inherited_scope)
      end

      def current_scope=(scope)
        ScopeRegistry.set_value_for(:current_scope, self, scope)
      end
    end
  end
end
