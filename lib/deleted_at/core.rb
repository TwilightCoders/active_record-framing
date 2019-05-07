require 'deleted_at/active_record'
require 'deleted_at/table'

module DeletedAt

  def self.scoped(scope=:present)
    Thread.currently(:deleted_at_scope, scope) do
      yield
    end
  end

  def self.scoped?(value=nil)
    a = value == nil
    b = scope == value
    c = scope != false

    (a && !b && c) || (!a && b)
  end

  def self.scope
    Thread.current[:deleted_at_scope]
  end

  module Core

    cattr_accessor :registry
    self.registry = {}

    def self.prepended(subclass)
      class << subclass
        cattr_accessor :deleted_at
        self.deleted_at = {}
      end

      subclass.extend(ClassMethods)
    end

    module ClassMethods

      def with_deleted_at(options={}, &block)
        self.deleted_at = DeletedAt::DEFAULT_OPTIONS.merge(options)
        self.deleted_at[:proc] = block if block_given?

        self.prepend(DeletedAt::ActiveRecord)
      end

    end # End ClassMethods

  end

end
