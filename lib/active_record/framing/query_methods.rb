require 'active_record/relation'

module ActiveRecord
  module Framing
    module QueryMethods

      if ::ActiveRecord.version >= Gem::Version.new("5.1") # 5.1+
        require 'active_record/framing/compat/active_record_5_1'
      elsif ::ActiveRecord.version >= Gem::Version.new("5.0") # 5.0+
        require 'active_record/framing/compat/active_record_5_0'
      elsif ::ActiveRecord.version >= Gem::Version.new("4.2") # 4.2+
        require 'active_record/framing/compat/active_record_4_2'
      else
        raise NotImplementedError, "ActiveRecord::Framing does not support Rails #{::ActiveRecord.version}"
      end

      # def from!(value, subquery_name = nil) # :nodoc:
      #   super.tap do |rel|
      #     if value.is_a?(::ActiveRecord::Relation) && value.frames_values.any?
      #       self.frames_values = self.frames_values.merge(value.frames_values)
      #       value.frames_values.clear
      #     end
      #   end
      # end

      # def frame(value)
      #   spawn.frame!(value)
      # end

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
