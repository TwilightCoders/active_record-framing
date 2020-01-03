require 'active_record/framing/model_proxy'

module ActiveRecord
  # = Active Record \Relation
  module Framing
    module Relation

      def initialize(*args)
        super.tap do |something|
          @klass = ModelProxy.new(@klass, arel_table) unless @klass.class == ModelProxy
        end
      end

      def build_arel(*)
        @klass.reframe_values = reframe_values
        super.tap do |ar|
          unless ignore_default_frame?
            build_frames(ar)
            ar.with(*frames_values.values) if frames_values.any?
          end
        end
      end

      # Prevents a scope from re-including the default_scope
      # e.g. User::All.all.to_sql yielding
      # WITH "all/users" AS (SELECT "users".* FROM "users"), "users" AS (SELECT "users".* FROM "users" WHERE "users"."kind" = 1) SELECT "all/users".* FROM "all/users"
      # vs.
      # WITH "all/users" AS (SELECT "users".* FROM "users") SELECT "all/users".* FROM "all/users"
      def all
        spawn
      end

      def table=(value)
        @table = value
        @klass.table = value
      end

      def aggregate_column(column_name)
        framing { super }
      end

      def build_joins(*)
        framing { super }
      end

      # This is all very unfortunate (rails 4.2):
      # ActiveRecord—in it's infinite wisdom—has decided
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
        # NOTE: We cannot early exclude associations because some associations are different from their table names
        # TODO: cache known associations, (renable warning)
        assocs = klass.reflect_on_all_associations.inject(Hash.new) do |assocs, assoc|
          begin
            assocs[assoc.name] = assoc
          rescue NameError => e
            # warn <<~WARN.chomp
            #   ActiveRecord::Framing was trying to inspect the association #{assoc.name}
            #     on the #{assoc.active_record.name} model but seems there is an issue
            #     locating the model backing it.
            #     Error: #{e.message}
            # WARN
          end
          assocs
        end

        manager.join_sources.each do |join_source|
          next unless join_source&.left&.respond_to?(:name)
          table = join_source.left
          if (join_class = derive_engine(table, assocs))
            frame!(join_class)
          end
        end

        reframe_values.each do |assoc_name, relation|
          relation.frames_values.values.each do |value|
            original = frames_values.delete(value.left.engine.table_name)
            frame!(value)
          end
        end
      end

      def derive_engine(table, associations)
        if table.engine == ::ActiveRecord::Base
          associations[table.name]
        else
          table.engine
        end
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

    end
  end
end
