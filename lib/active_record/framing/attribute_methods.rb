module ActiveRecord
  module Framing
    module AttributeMethods
      extend ActiveSupport::Concern

      RESTRICTED_FRAME_CONSTS = %w(unframed).freeze
      # Deprecated alias, kept for backwards compatibility.
      BLACKLISTED_CLASS_CONSTS = RESTRICTED_FRAME_CONSTS

      module ClassMethods
        # A class const is 'dangerous' if it is already defined by Active Record, but
        # not by any ancestors. (So 'All' is not dangerous but 'Frameless' is.)
        def dangerous_class_const?(const_name)
          RESTRICTED_FRAME_CONSTS.include?(const_name.to_s) || class_const_defined_within?(const_name, Base)
        end

        def class_const_defined_within?(name, klass, superklass = klass.superclass) # :nodoc:
          klass.const_defined?(name) || superklass.const_defined?(name)
        end
      end
    end
  end
end
