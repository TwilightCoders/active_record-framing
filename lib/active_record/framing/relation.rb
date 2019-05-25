require 'active_record/framing/dependency'

module ActiveRecord
  # = Active Record \Relation
  module Framing
    module Relation

      def self.prepended(klass)

        klass.class_eval do
          attr_reader :join_dependency

          def join_dependency=(value)
            @join_dependency = value
          end
        end
      end

      def build_arel(*)
        super.tap do |ar|
          unless ignore_default_frame?
            # alias_tracker.aliased_table_for(
            #   reflection.table_name,
            #   table_alias_for(reflection, parent, reflection != node.reflection),
            #   reflection.klass.type_caster
            # )
            build_frames(ar)
            ar.with(*frames_values.values) if frames_values.any?
          end
        end
      end

      # This is all very unfortunate (rails 4.2):
      # ActiveRecord, in it's infinite wisdom, has decided
      # to create JoinDependency objects with arel_tables using a
      # generic engine (ActiveRecord::Base) as opposed to that of
      # the driving class. For example:
      #
      # #<Arel::Nodes::InnerJoin:0x00007f974e6eb008
      #  @left=
      #   #<Arel::Table:0x00007f97508f42f8
      #    @aliases=[],
      #    @columns=nil,
      #    @engine=ActiveRecord::Base,     <=== Problem, should be `User`
      #    @name="users",
      #    @primary_key=nil,
      #    @table_alias=nil>,
      # NOTE: In Rails 5.2 (at least) we could use the InnerJoin.left.type_caster
      def build_frames(manager)
        # Notes for picking up where we left off.
        # 1. We need to merge in all joins that have a frame (current/default)
        #  1.a The best way so far is to just merge in .all on the "engine"
        #      (see point 2) or if it's a relation like in a reframe
        #      (see point 3) then just merge that in
        #      The trick with with the a reframe is the need to update all the
        #      arel engines
        # 2. We need to loop through all the join sources to find the "engine"
        #    that is associated with the join. We can do this in a few ways.
        #  2.a We can reflect on all the associations of the class at hand, and
        #      compare those (the table name?) to the present join sources
        #  2.b We can look at the joins_sources and use those keys to find the
        #      associations that are on the class and compare those to the
        #      reframe values present

        # sm = select_manager
        # bj = build_joins(sm, joins_values.flatten) unless joins_values.empty?

        # NOTE: We cannot early exclude associations because
        #       some associations are different from their table names
        # TODO: cache known associations?
        assocs = klass.reflect_on_all_associations.inject(Hash.new) do |assocs, assoc|
          begin
            assocs[assoc.table_name] = assoc
          rescue NameError => e
            # warn <<~WARN.chomp
            #   ActiveRecord::Framing was trying to inspect the association #{assoc.name}
            #     on the #{assoc.active_record.name} model but seems there is an issue
            #     locating the model backing it.
            # WARN
          end
          assocs
        end

        # reframes = ::ActiveRecord::Framing::Dependency.make_tree(reframe_values.flatten)
        # joins = manager.join_sources.inject(Hash.new) { |hash, join| hash.merge(join.left.table_name => join) }

        # joins = manager.join_sources
        # binding.pry if $break && reframes.any?
        # reframes = ::ActiveRecord::Associations::JoinDependency.make_tree(reframe_values.flatten)
        binding.pry if manager.join_sources.any?
        # frames = walk_frames(base, reframes, Hash.new)
        # frame_joins(manager.join_sources, frames)
      end

      if ::ActiveRecord.version >= Gem::Version.new("5.0") # 5.0+
        def extract_engine(arel_node)
          arel_node.send(:type_caster).send(:types)
        end
      elsif ::ActiveRecord.version >= Gem::Version.new("4.2") # 4.2+
        def extract_engine(arel_node)
          arel_node&.right&.expr&.children&.first&.right&.relation&.engine
        end
      end

      def walk_frames(base, frames, hash)
        # frames = {:posts=>{:comments=>{:votes=>Vote::Revoked}, posts: nil }
        frames.inject(hash) do |h, (k, v)|
          ar = base.reflect_on_association(k).active_record
          case v
          when Hash
            walk_frames(ar, v, h)
          else
            h[ar] = v
          end
          h
        end
        # {
        #   User =>  {
        #     associations: {},
        #     frame: User::All
        #   },
        #   Post => {
        #     associations: {
        #       Vote => {
        #         frame: Vote::Revoked,
        #         associations: {
        #           User => {
        #             frame: User::Deleted
        #           }
        #         }
        #       }
        #     }
        #   }
        # }
      end

      def frame_joins(joins, reframes)
        # puts "processing #{reframes.inspect} on #{base.name} for #{joins.keys}"

        # joins = ::ActiveRecord::Associations::JoinDependency.make_tree(joins_values.flatten)

        joins.each do |join|
          at = join.left
          join_class = extract_engine(at)
          binding.pry

          frame = if (reframed = reframes[join_class])
            at.table_name = reframed.table_name
            reframed
          else
            join_class.all
          end

          merge!(frame) if frame
        end









        # reframes.each do |key, data|
        #   if (assoc = base.reflect_on_association(key))
        #     if (join = joins[key] || joins[assoc.klass.table_name])
        #       frame = case data[:relation]
        #         when ::ActiveRecord::Base
        #           data[:relation].all
        #         when ::ActiveRecord::Relation
        #           data[:relation]
        #         when nil
        #           assoc.klass.all
        #         end
        #         binding.pry
        #       puts "reframing #{key}(#{join.left.name}) as #{frame.arel_table.name}"
        #       join.left.name = frame.arel_table.name
        #       merge!(frame)
        #     end
        #     walk_frames(assoc.klass, data[:associations], joins) if data[:associations]
        #   end
        # end


        # ::ActiveRecord::Associations::JoinDependency.make_tree(joins_values.flatten)
        # manager.join_sources.each do |join_source|
        #   next unless join_source&.left&.respond_to?(:name)
        #   if assoc = assocs[join_source.left.name]
        #     source = reframes.fetch(assoc.name) { assoc.klass }

        #     join_source.left.name = source.arel_table.name
        #     if source < ::ActiveRecord::Base
        #       merge!(source.all)
        #     elsif source < ::ActiveRecord::Relation
        #       merge!(source)
        #     end
        #   end
        # end
      end

<<<<<<< HEAD
=======
      def frame_key(cte)
        case cte
        when ActiveRecord::Relation
          cte.table.name
        when Arel::Nodes::As
          cte.left.name
        when String
          cte
        else
          nil
        end
      end

      # def reframe(*args) # :nodoc:
      #   args.compact!
      #   args.flatten!
      #   # binding.pry
      #   self
      # end

      # def reframe!(*args) # :nodoc:
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

>>>>>>> ac96e0b... Scaffolding for deep reframes
      # Frame all queries to the current frame.
      #
      #   Comment.where(post_id: 1).framing do
      #     Comment.first
      #   end
      #   # => WITH "comments" AS (
      #   # =>   SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1
      #   # => ) SELECT "comments".* FROM "comments" ORDER BY "comments"."id" ASC LIMIT 1
      #
      # Please check unframed if you want to remove all previous frames (including
      # the default_frame) during the execution of a block.
      def framing
        previous, klass.current_frame = klass.current_frame, self unless @delegate_to_klass
        yield
      ensure
        klass.current_frame = previous unless @delegate_to_klass
      end

      def scoping
        framing { super }
      end

      # def _exec_frame(*args, &block) # :nodoc:
      #   @delegate_to_klass = true
      #   instance_exec(*args, &block) || self
      # ensure
      #   @delegate_to_klass = false
      # end

      # def frame_for_create
      #   where_values_hash.merge!(create_with_value.stringify_keys)
      # end

      # def empty_frame? # :nodoc:
      #   @values == klass.unframed.values
      # end

    end
  end
end
