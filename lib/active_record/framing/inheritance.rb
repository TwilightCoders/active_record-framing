module ActiveRecord
  module Framing
    module Inheritance

      def self.prepended(subclass)
        subclass.extend ClassMethods
      end

      module ClassMethods
        # def type_condition(table = arel_table)
        #
        #   super.tap do |ar|
        #     ar.right = ar.right.inject(Hash.new) do |collector, condition|
        #       collector[condition.attribute]
        #
        #     end
        #   end
        # end
      end

    end
  end
end
