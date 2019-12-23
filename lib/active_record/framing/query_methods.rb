require 'active_record/relation'

module ActiveRecord
  module Framing
    module QueryMethods

      def frame(value)
        spawn.frame!(value)
      end

      def frame!(value)
        value = value.all if (value.is_a?(Class) && value < ::ActiveRecord::Base)

        cte = \
          case value
          when ::ActiveRecord::Relation
            # {value.table.name => value.frames_values}
            value.frames_values
          when Arel::Nodes::As
            {value.left.name => value}
          when String
            {arel_table.name => value}
          when Hash
            value
          else
            {}
          end

        self.frames_values = self.frames_values.merge(cte)

        self
      end

      def reframe(*args)
        spawn.reframe!(*args)
      end

      # TODO: Consistent keys class: symbol, string, Arel::Table
      def reframe!(*args)
        args.flatten!
        # TODO: Convert array (if present) to nil hash {value => nil}
        # and merge with hash (if present) as second arg
        self.reframe_values = self.reframe_values.merge(args.first)
        self
      end
    end
  end
end
