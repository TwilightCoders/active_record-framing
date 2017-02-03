require 'deleted_at/views'
require 'deleted_at/active_record/relation'

module DeletedAt
  module ActiveRecord
    module Base
      extend ActiveSupport::Concern

      included do
        class_attribute :deleted_at_column, :original_table_name,
          :deleted_by_column, :deleted_by_class, :deleted_by_primary_key

        class << self
          [:archive_with_deleted_at?, :archive_with_deleted_by?].each do |sym|
            define_method(sym) do
              false
            end
          end
          alias_method_chain :create, :deleted_at
        end

      end

      module ClassMethods

        def create_with_deleted_at(attributes = nil, &block)
          if archive_with_deleted_at?
            const_get(:All).create_without_deleted_at(attributes, &block)
          else
            create_without_deleted_at
          end
        end

        def with_deleted_at(options={})

          parse_options(options)

          unless ::DeletedAt::Views.all_table_exists?(self) && ::DeletedAt::Views.deleted_view_exists?(self)
            return warn("You're trying to use `with_deleted_at` on #{name} but you have not installed the views, yet.")
          end

          unless columns.map(&:name).include?(deleted_at_column)
            return warn("Missing `#{deleted_at_column}` in `#{name}` when trying to employ `deleted_at`")
          end

          [:archive_with_deleted_at?, :archive_with_deleted_by?].each do |sym|
            class_eval <<-BBB
              def self.#{sym}
                true
              end
            BBB
          end


          # We are confident at this point that the tables and views have been setup.
          # We need to do a bit of wizardy by setting the table name to the actual table
          # (at this point: model/all), such that the model has all the information
          # regarding its structure and intended behavior. Calling primary_key loads the
          # table data into the class.
          self.original_table_name = self.table_name
          self.table_name = ::DeletedAt::Views.all_table(self)
          primary_key = self.primary_key
          self.table_name = self.original_table_name

          setup_class_views
          with_deleted_by

        end

        private

        def parse_options(options)
          self.deleted_at_column      = (options.try(:[], :deleted_at).try(:[], :column) || :deleted_at).to_s
          self.deleted_by_column      = (options.try(:[], :deleted_by).try(:[], :column) || :deleted_by).to_s
          self.deleted_by_class       = (options.try(:[], :deleted_by).try(:[], :class) || User)
          self.deleted_by_primary_key = (options.try(:[], :deleted_by).try(:[], :primary_key) || deleted_by_class.try(:primary_key)).to_s
        end

        def deleted_by_class_is_delete_at(klass)
          klass && (klass.archive_with_deleted_at? || self == klass)
        end

        def with_deleted_by
          return unless (deleted_by_column && columns.map(&:name).include?(deleted_by_column) && deleted_by_class < ActiveRecord::Base)
          self.deleted_by_class       = self.deleted_by_class.const_get(:All) if deleted_by_class_is_delete_at(self.deleted_by_class)

          unless reflect_on_association(:destroyer)
            class_eval do
              belongs_to :destroyer, foreign_key: deleted_by_column, primary_key: deleted_by_primary_key, class_name: deleted_by_class.name
            end
          end
        end

        def refactor_validators
          validators.each do |validator|
            case validator
            when ActiveRecord::Validations::UniquenessValidator

            end
          end
        end

        def setup_class_views

          self.const_set(:All, Class.new(self) do |klass|
            class_eval <<-AAA
              self.table_name = '#{::DeletedAt::Views.all_table(klass)}'
            AAA
          end)

          self.const_set(:Deleted, Class.new(self) do |klass|
            class_eval <<-AAA
              self.table_name = '#{::DeletedAt::Views.deleted_view(klass)}'
            AAA
          end)
        end

      end

      [:archive_with_deleted_at?, :archive_with_deleted_by?].each do |sym|
        class_eval <<-BBB
          def #{sym}
            self.class.#{sym}
          end
        BBB
      end

      def destroy
        if archive_with_deleted_at?
          with_transaction_returning_status do
            run_callbacks :destroy do
              update_columns(deleted_at_attributes)
              self
            end
          end
        else
          super
        end
      end

      private

      def deleted_at_attributes
        attributes = {
          deleted_at_column => Time.now.utc
        }

        # attributes.merge({
        #   deleted_by_column => DeletedAt::who_by
        # }) if by_who?

        attributes
      end

      def deleted_at_column
        self.class.deleted_at_column
      end

      def deleted_by_column
        self.class.deleted_by_column
      end

    end
  end
end
