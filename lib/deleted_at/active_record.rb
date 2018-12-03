require 'active_record'
require 'deleted_at/relation'

module DeletedAt
  module ActiveRecord

    def self.prepended(subclass)
      subclass.init_deleted_at_relations
      subclass.extend(ClassMethods)
    end

    def initialize(*args)
      super
      @destroyed = !deleted_at.nil?
    end



    private


    module ClassMethods

      def inherited(subclass)
        super
        subclass.init_deleted_at_relations
      end

      def const_missing(const)
        case const
        when :All, :Deleted, :Present
          all.tap do |rel|
            rel.deleted_at_scope = const
          end
        # when :All
        #   current_scope = all.with_deleted
        # when :Deleted
        #   current_scope = all.only_deleted
        else super
        end
      end

    end

  end

end
