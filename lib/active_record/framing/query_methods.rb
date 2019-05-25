module ActiveRecord
  module Framing
    module QueryMethods

      if ::ActiveRecord.version > Gem::Version.new("5.2") # 6.0+
        require 'active_record/framing/compat/active_record_6_0'
      elsif ::ActiveRecord.version >= Gem::Version.new("5.1") # 5.1+
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
        self.reframe_values += args
        self
      end

      # Removes an unwanted relation that is already defined on a chain of relations.
      # This is useful when passing around chains of relations and would like to
      # modify the relations without reconstructing the entire chain.
      #
      #   User.order('email DESC').unframe(:order) == User.all
      #
      # The method arguments are symbols which correspond to the names of the methods
      # which should be unframed. The valid arguments are given in VALID_UNSCOPING_VALUES.
      # The method can also be called with multiple arguments. For example:
      #
      #   User.order('email DESC').select('id').where(name: "John")
      #       .unframe(:order, :select, :where) == User.all
      #
      # One can additionally pass a hash as an argument to unframe specific +:where+ values.
      # This is done by passing a hash with a single key-value pair. The key should be
      # +:where+ and the value should be the where value to unframe. For example:
      #
      #   User.where(name: "John", active: true).unframe(where: :name)
      #       == User.where(active: true)
      #
      # This method is similar to #except, but unlike
      # #except, it persists across merges:
      #
      #   User.order('email').merge(User.except(:order))
      #       == User.order('email')
      #
      #   User.order('email').merge(User.unframe(:order))
      #       == User.all
      #
      # This means it can be used in association definitions:
      #
      #   has_many :comments, -> { unframe(where: :trashed) }
      #
      # def unframe(*args)
      #   check_if_method_has_arguments!(:unframe, args)
      #   spawn.unframe!(*args)
      # end

      # def unframe!(*args) # :nodoc:
      #   args.flatten!
      #   self.unframe_values += args

      #   args.each do |frame|
      #     case frame
      #     when Symbol
      #       frame = :left_outer_joins if frame == :left_joins
      #       if !VALID_UNSCOPING_VALUES.include?(frame)
      #         raise ArgumentError, "Called unframe() with invalid unframing argument ':#{frame}'. Valid arguments are :#{VALID_UNSCOPING_VALUES.to_a.join(", :")}."
      #       end
      #       set_value(frame, DEFAULT_VALUES[frame])
      #     when Hash
      #       frame.each do |key, target_value|
      #         if key != :where
      #           raise ArgumentError, "Hash arguments in .unframe(*args) must have :where as the key."
      #         end

      #         target_values = Array(target_value).map(&:to_s)
      #         self.where_clause = where_clause.except(*target_values)
      #       end
      #     else
      #       raise ArgumentError, "Unrecognized framing: #{args.inspect}. Use .unframe(where: :attribute_name) or .unframe(:order), for example."
      #     end
      #   end

      #   self
      # end
    end
  end
end
