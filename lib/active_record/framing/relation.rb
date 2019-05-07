module ActiveRecord
  # = Active Record \Relation
  module Framing
    module Relation

      # Rails 4.2: def initialize(klass, table, values = {})
      # Rails 5.2: def initialize(klass, table: klass.arel_table, predicate_builder: klass.predicate_builder, values: {})
      def initialize(*)
        super
        # @frames = {}
      end

      def initialize_copy(other)
        super
        # @frames = @frames.dup
      end

      # def arel_attribute(name) # :nodoc:
      #   klass.arel_attribute(name, table)
      # end

      def table
        # if frame = (klass.current_frame || klass.default_framed)
        #   if (at = frame.left) === ::Arel::Table
        #     return at
        #   end
        # end
        #attr_accessor
        super
      end


      def arel_without_frames
        klass.ignore_default_frame
        Thread.currently(:without_frames, true) do
          @arel_without_frames ||= build_arel_without_frames
        end
      end

      def build_arel_without_frames
        @arel, old = nil, @arel
        arel
      ensure
        @arel = old
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
            frames = frames_values

            frames.each do |k,v|
              puts "#{k} => #{v.to_sql}"
            end

            ar.with(*frames.values) if frames.any?
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
        join_names = manager.join_sources.collect do |source|
          source.left.name.to_s # TODO: Need to_s?
        end

        # scopes = klass.reflections.slice(*join_names).values.inject(Hash.new) do |collector, assoc|
        # NOTE: We cannot early exclude associations because some associations are different from their table names
        klass.reflect_on_all_associations.each do |assoc|
          # collector.merge(assoc.klass.default_scopes) if join_names.include?(assoc.table_name)
          # (collector[assoc.klass] ||= Set.new).merge(assoc.klass.default_scopes) if join_names.include?(assoc.table_name) && assoc.klass.default_scopes.any?
          if join_names.include?(assoc.table_name) && assoc.klass.default_frames.any? && assoc_default_frame = assoc.klass.send(:build_default_frame)
            merge!(assoc_default_frame)
            # collector[assoc_default_frame.table_name] ||= assoc_default_frame
          end

          # collector
        end
      end

      def from!(value, subquery_name = nil) # :nodoc:
        super.tap do |rel|
          frames_values = frames_values.merge(value.frames_values) if value.is_a?(::ActiveRecord::Relation)
        end
      end

      def frame(value)
        spawn.frame!(value)
      end

      def frame!(value)
        if key = frame_key(value)
          self.frames_values = self.frames_values.merge(key => value)
        end
        self
      end

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

      def reframe(*)
        self
      end

      def unframe(*)
        self
      end

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

      def _exec_frame(*args, &block) # :nodoc:
        @delegate_to_klass = true
        instance_exec(*args, &block) || self
      ensure
        @delegate_to_klass = false
      end

      def frame_for_create
        where_values_hash.merge!(create_with_value.stringify_keys)
      end

      def empty_frame? # :nodoc:
        @values == klass.unframed.values
      end

    end
  end
end
