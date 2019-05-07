require 'active_record'
require 'deleted_at/relation'

module DeletedAt
  module ActiveRecord

    def self.prepended(subclass)
      subclass.extend(ClassMethods)

      class << subclass

        alias_method :base_arel_table, :arel_table
        def arel_table
          base_arel_table
        end

      end
    end

  private

    module ClassMethods

      def default_scoped # :nodoc:
        relation.merge(build_default_scope)
      end

      # def relation
      #   super.
      # end

      def all
        super
        # if current_scope
        #   current_scope.clone
        # else
        #   default_scoped
        # end
      end

    end
  end
end
