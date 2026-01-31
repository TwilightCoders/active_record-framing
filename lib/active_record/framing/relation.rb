require 'active_record/framing/model_proxy'

module ActiveRecord
  # = Active Record \Relation
  module Framing
    module Relation

      def initialize(*args)
        super.tap do |something|
          unless @klass.class == ModelProxy
            @klass = ModelProxy.new(@klass, arel_table)
            @table = arel_table
          end
        end
      end

      def build_arel(*)
        @klass.reframe_values = reframe_values

        super.tap do |ar|
          unless ignore_default_frame?
            build_frames(ar)

            if frame_clause.any?
              # IMPORTANT: Cache binds BEFORE compiling to Arel
              # Unlike WHERE clause subqueries (which use PredicateBuilder to extract binds),
              # CTEs don't have automatic bind extraction. We must cache bound_attributes
              # from Relations before converting to Arel, because Arel nodes don't retain
              # the connection to bound_attributes.
              frame_clause.binds

              # Compile frame Relations to Arel CTEs
              frame_ctes = frame_clause.to_arel_ctes
              ar.with(*frame_ctes)
            end
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
        reframe_values_copy = reframe_values.dup
        assocs = klass.reflect_on_all_associations.inject(Hash.new) do |assocs, assoc|
          begin
            if (reframe_value = reframe_values_copy.delete(assoc.name))
              reframe_values_copy[assoc.klass.table_name] = reframe_value
            end
            assocs[assoc.name] = assoc
          rescue NameError => e
            # Silently skip associations that can't be resolved
          end
          assocs
        end

        manager.join_sources.each do |join_source|
          next unless join_source&.left&.respond_to?(:name)
          source_table = join_source.left
          if (join_class = derive_engine(source_table, assocs))
            reframe_source = reframe_values_copy.fetch(join_class.table_name) { join_class.all }
            reframe_cte = frame_cte_for(reframe_source)
            frame!(reframe_cte)
            fix_right_side(join_source.right, reframe_source.arel_table, source_table) if reframe_source
          end
        end

        reframe_values_copy.each do |assoc_name, relation|
          relation.frame_clause.frames.each do |frame_name, frame_relation|
            # frame_relation is now a Relation object
            # Get the table name from the relation's klass
            table_name = frame_relation.klass.table_name
            original = reframe_values_copy.fetch(table_name, {})
            frame!(frame_name => frame_relation)
          end
        end
      end

      def derive_engine(source_table, associations)
        if source_table.engine == ::ActiveRecord::Base
          associations[source_table.name]
        else
          source_table.engine
        end
      end

      def fix_right_side(arel, from_table, to_table)
        case arel
        when Arel::Nodes::On, Arel::Nodes::Grouping
          fix_right_side(arel.expr, from_table, to_table)
        when Arel::Nodes::And
          fix_right_side(arel.children, from_table, to_table)
        when Array
          arel.each do |a1|
            fix_right_side(a1, from_table, to_table)
          end
        when Arel::Nodes::Binary
          fix_right_side(arel.left, from_table, to_table)
          fix_right_side(arel.right, from_table, to_table)
        when Arel::Nodes::Casted
          fix_right_side(arel.attribute, from_table, to_table)
        when Arel::Attributes::Attribute
          if arel.relation.name == from_table.name
            arel.relation = to_table
          else
            warn "#{arel.relation.name} != #{from_table.name} for #{arel.name}"
          end
        when Arel::Nodes::BindParam
          # Nothing (must come before Arel::Nodes::Node)
        when Arel::Nodes::Node
          fix_right_side(arel.value, from_table, to_table)
        else
          # No Op
        end
      end

      # Override bound_attributes to include frame bind values
      # Frame binds must come first because CTEs are defined before the main query
      # When prepared_statements=false, returns empty array because binds are already
      # substituted into CTE SQL (frame_clause.binds returns [])
      def bound_attributes
        if ignore_default_frame? || frame_clause.empty?
          super
        else
          frame_clause.binds + super
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
        previous, klass.current_frame = klass.current_frame(true), self unless @delegate_to_klass
        yield
      ensure
        klass.current_frame = previous unless @delegate_to_klass
      end

    end
  end
end
