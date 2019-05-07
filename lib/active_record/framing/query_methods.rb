module ActiveRecord
  module Framing
    module QueryMethods

      if ::ActiveRecord.version >= Gem::Version.new("5.1") # 5.1+
        def frames_values
          get_value(:frames)
        end
        def frames_values=(value)
          set_value(:frames, value)
        end
        ::ActiveRecord::Relation::DEFAULT_VALUES[:frames] = ::ActiveRecord::Relation::FROZEN_EMPTY_HASH
      elsif ::ActiveRecord.version >= Gem::Version.new("5.0") # 5.0+
        def frames_values
          @values[:frames] || FROZEN_EMPTY_HASH
        end
        def frames_values=(values)
          assert_mutability!
          @values[:frames] = values
        end
      elsif ::ActiveRecord.version >= Gem::Version.new("4.2") # 4.2+
        def frames_values
          @values[:frames] || {}
        end
        def frames_values=(values)
          raise ImmutableRelation if @loaded
          check_cached_relation
          @values[:frames] = values
        end
      else
        binding.pry
        warn "Ruh-Roh"
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
      def unframe(*args)
        check_if_method_has_arguments!(:unframe, args)
        spawn.unframe!(*args)
      end

      def unframe!(*args) # :nodoc:
        args.flatten!
        self.unframe_values += args

        args.each do |frame|
          case frame
          when Symbol
            frame = :left_outer_joins if frame == :left_joins
            if !VALID_UNSCOPING_VALUES.include?(frame)
              raise ArgumentError, "Called unframe() with invalid unframing argument ':#{frame}'. Valid arguments are :#{VALID_UNSCOPING_VALUES.to_a.join(", :")}."
            end
            set_value(frame, DEFAULT_VALUES[frame])
          when Hash
            frame.each do |key, target_value|
              if key != :where
                raise ArgumentError, "Hash arguments in .unframe(*args) must have :where as the key."
              end

              target_values = Array(target_value).map(&:to_s)
              self.where_clause = where_clause.except(*target_values)
            end
          else
            raise ArgumentError, "Unrecognized framing: #{args.inspect}. Use .unframe(where: :attribute_name) or .unframe(:order), for example."
          end
        end

        self
      end
    end
  end
end
