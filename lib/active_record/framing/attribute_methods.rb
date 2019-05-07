module ActiveRecord
  module Framing
    module AttributeMethods
      extend ActiveSupport::Concern

      BLACKLISTED_CLASS_CONSTS = %w(unframed)

      module ClassMethods
        # A class const is 'dangerous' if it is already defined by Active Record, but
        # not by any ancestors. (So 'All' is not dangerous but 'Frameless' is.)
        def dangerous_class_const?(const_name)
          BLACKLISTED_CLASS_CONSTS.include?(const_name.to_s) || class_const_defined_within?(const_name, Base)
        end

        def class_const_defined_within?(name, klass, superklass = klass.superclass) # :nodoc:
          klass.const_defined?(name) || superklass.const_defined?(name)
        end
      end
    end
  end
end
