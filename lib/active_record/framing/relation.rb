module ActiveRecord
  # = Active Record \Relation
  module Framing
    module Relation

      def build_arel(*)
        super.tap do |ar|
          unless ignore_default_frame?
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
        # NOTE: We cannot early exclude associations because some associations are different from their table names
        # TODO: cache known associations, (renable warning)
        assocs = klass.reflect_on_all_associations.inject(Hash.new) do |assocs, assoc|
          begin
            assocs[assoc.table_name] = assoc
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
          if (assoc = assocs[join_source.left.name])
            source = reframe_values.fetch(assoc.name) { assoc.klass }

            join_source.left.name = source.arel_table.name
            if source < ::ActiveRecord::Base
              merge!(source.all)
            elsif source < ::ActiveRecord::Relation
              merge!(source)
            end
          end
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

      def scoping
        framing { super }
      end
    end
  end
end
