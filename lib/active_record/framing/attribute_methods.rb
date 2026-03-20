module ActiveRecord
  module Framing
    module AttributeMethods
      extend ActiveSupport::Concern

      RESTRICTED_FRAME_CONSTS = %w(unframed).freeze

      module ClassMethods
        def dangerous_class_const?(const_name)
          RESTRICTED_FRAME_CONSTS.include?(const_name.to_s) || class_const_defined_within?(const_name, Base)
        end

        def class_const_defined_within?(name, klass, superklass = klass.superclass)
          klass.const_defined?(name) || superklass.const_defined?(name)
        end
      end
    end
  end
end
