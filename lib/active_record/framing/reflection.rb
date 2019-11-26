module ActiveRecord
  module Framing
    module Reflection

      def self.prepended(subclass)
        class << subclass
          prepend ClassMethods
        end
      end

      module ClassMethods

        def add_reflection(ar, name, reflection)
          super.tap do |reflections|
            #
            # puts "foo"
          end
        end
      end
    end
  end
end

module ActiveRecord
  module Framing
    module MacroReflection

      def self.prepended(subclass)
        class << subclass
          attr_reader :frame
        end
      end

    end
  end
end
