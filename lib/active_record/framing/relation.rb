module ActiveRecord
  # = Active Record \Relation
  module Framing
    module Relation

      def initialize(*args, **kwargs)
        super.tap do |something|
          # Use @table if already set (from parent relation) AND we have a frame_clause.
          # For unframed relations (no frame_clause), reset to base arel_table.
          # This preserves a framed table across spawns while keeping `klass` the
          # real model class (framed tables flow through @table + current_frame,
          # not through a SimpleDelegator wrapper).
          has_frames = frame_clause && !frame_clause.empty?
          @table = (has_frames && @table) ? @table : arel_table
        end
      end

      def build_arel(*)
        klass.reframe_values = reframe_values

        # Set current_frame for each reframed association BEFORE building Arel.
        # This ensures that when the target class's arel_table is called during
        # JOIN building, it returns the framed table instead of the base table.
        # This eliminates the need for invasive tree-walking to fix table references.
        previous_frames = {}
        reframe_values.each do |assoc_name, reframe_relation|
          # Get the association to find the target class
          if (assoc = klass.reflect_on_association(assoc_name))
            target_klass = assoc.klass
            previous_frames[target_klass] = target_klass.current_frame
            target_klass.current_frame = reframe_relation
          end
        end

        super.tap do |ar|
          unless ignore_frames?
            build_frames(ar)

            # IMPORTANT: Cache binds BEFORE compiling to Arel
            # because calling .arel on relations consumes their bound_attributes
            # The FrameClause.binds method caches on first call
            frame_clause.binds unless frame_clause.empty?

            # Compile frame Relations to Arel CTEs at the last moment
            if frame_clause.any?
              frame_ctes = frame_clause.to_arel_ctes
              ar.with(*frame_ctes)
            end
          end
        end
      ensure
        # Restore previous current_frame values
        previous_frames&.each do |target_klass, previous_frame|
          target_klass.current_frame = previous_frame
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

      # Return the relation's own (possibly framed) table instead of delegating
      # to klass.arel_table. This terminates the recursion in the class-level
      # arel_table override (current_frame&.arel_table), which previously relied
      # on the ModelProxy to supply a concrete table.
      def arel_table
        @table || super
      end

      def table=(value)
        @table = value
        # Update PredicateBuilder's cached table reference.
        # CRITICAL: dup the PB first to avoid mutating shared instances.
        # The PB may be shared with @relation_without_type_condition or
        # the thread-local cache. Mutating it in-place would poison all
        # relations that share the same PB object.
        if @predicate_builder
          @predicate_builder = @predicate_builder.dup
          table_metadata = ::ActiveRecord::TableMetadata.new(klass, value)
          @predicate_builder.instance_variable_set(:@table, table_metadata)
        end
        # Invalidate WhereClauseFactory so it gets recreated with updated PredicateBuilder
        @where_clause_factory = nil
      end

      def aggregate_column(column_name)
        # The framing block sets current_frame, which makes arel_table return the framed table.
        # This ensures aggregations use the correct table reference.
        framing { super }
      end

      def build_joins(*)
        framing { super }
      end

      # Eager loading builds its JoinDependency root from klass.arel_table at
      # construction time (before build_arel runs), so frame the construction
      # to make the root resolve to the framed table. The ModelProxy used to
      # supply this by making klass.arel_table framed unconditionally.
      def apply_join_dependency(*args, **kwargs)
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
        # Step 1: Build associations lookup hash
        assocs = klass.reflect_on_all_associations.each_with_object({}) do |assoc, hash|
          hash[assoc.name] = assoc
        rescue NameError
          # Skip associations that can't be resolved
        end

        # Step 2: Convert reframe_values keys from association names to table names
        # Some associations use different names than their table names
        reframe_by_table = convert_association_keys_to_table_names(reframe_values, assocs)

        # Step 3: Frame each JOIN source
        manager.join_sources.each do |join_source|
          next unless join_source&.left&.respond_to?(:name)
          source_table = join_source.left
          if (join_class = derive_engine(source_table, assocs))
            reframe_source = reframe_by_table.fetch(join_class.table_name) { join_class.all }
            reframe_cte = frame_cte_for(reframe_source)
            frame!(reframe_cte)
          end
        end

        # Step 4: Add any nested frames from reframed relations
        reframe_by_table.each_value do |relation|
          relation.frame_clause.frames.each do |cte_table, frame_relation|
            frame!(cte_table => frame_relation)
          end
        end
      end

      # Convert reframe_values keys from association names to table names.
      # Example: { posts: Post::Deleted } => { "documents" => Post::Deleted }
      def convert_association_keys_to_table_names(reframe_vals, associations)
        reframe_vals.each_with_object({}) do |(key, value), result|
          if (assoc = associations[key])
            # Key is an association name, use its table name
            result[assoc.klass.table_name] = value
          else
            # Key is already a table name or something else
            result[key] = value
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

      # Override bound_attributes to include bind values from frame Relations.
      # Frame bind values must come first because the CTE is defined first in the SQL.
      # NOTE: In Rails 6+, bound_attributes was removed. Binds are now embedded in Arel nodes.
      # This method is only called in Rails 5.x (Rails 6 doesn't use this API)
      def bound_attributes
        if ignore_frames? || frame_clause.empty?
          super
        else
          # Prepend frame binds to the regular bound_attributes
          # The FrameClause caches binds on first call to avoid recompiling relations
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
      # Executes a block with custom frame context, or returns a framed relation.
      #
      # Options:
      #   skip_default_frame: If true, removes all frames (including default_frame)
      #   skip_inherited_frame: If true, ignores frames from parent classes
      #
      #   Comment.where(post_id: 1).framing do
      #     Comment.first  # Uses the where(post_id: 1) frame
      #   end
      #
      #   Comment.framing(skip_default_frame: true)  # Returns unframed relation
      #
      # Please check unframed if you want to remove all frames.
      def framing(skip_default_frame: false, skip_inherited_frame: false)
        previous_frame = klass.current_frame(skip_inherited_frame: skip_inherited_frame) unless framing_delegate_to_model?

        relation_to_use = skip_default_frame ? spawn_without_frames : self

        if block_given?
          klass.current_frame = relation_to_use unless framing_delegate_to_model?
          yield
        else
          relation_to_use
        end
      ensure
        klass.current_frame = previous_frame unless framing_delegate_to_model?
      end

      # Removes all frames (including default_frame and inherited frames) from this relation.
      # Preserves default_scope (WHERE conditions) but removes the CTE wrapping.
      #
      #   Post::Deleted.unframed.to_sql
      #   # => SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NOT NULL
      #   # (no CTE, but default_scope's WHERE clause is preserved)
      #
      # Accepts a block to temporarily remove frames:
      #
      #   Post::Deleted.unframed do
      #     Post.first  # Uses base table without frames
      #   end
      def unframed(&block)
        framing(skip_default_frame: true, skip_inherited_frame: true, &block)
      end

      # Override mutation methods to convert frames to WHERE conditions
      # Frames are CTEs which cannot be updated/deleted directly
      # Instead, we need to use the base table with the frame's WHERE conditions

      def update_all(updates)
        if frame_clause.empty?
          super
        else
          as_mutation_relation.update_all(updates)
        end
      end

      def delete_all
        if frame_clause.empty?
          super
        else
          as_mutation_relation.delete_all
        end
      end

      def destroy_all
        if frame_clause.empty?
          super
        else
          as_mutation_relation.destroy_all
        end
      end

    private

      # Rails 7.2 renamed Relation's @delegate_to_klass ivar to @delegate_to_model.
      # Read whichever this activerecord version defines.
      def framing_delegate_to_model?
        instance_variable_defined?(:@model) ? @delegate_to_model : @delegate_to_klass
      end

      # Spawns a new relation with all frames cleared.
      # Clears frame_clause, resets table to base arel_table, and temporarily clears current_frame.
      # Saves and restores current_frame to avoid polluting class-level state.
      def spawn_without_frames
        saved_frame = klass.current_frame
        klass.current_frame = nil

        FrameRegistry.set_value_for(:ignore_frames, klass.base_class, true)
        spawn.tap do |r|
          r.frame_clause = FrameClause.new({})
          r.table = klass.unframed_arel_table
        end
      ensure
        FrameRegistry.set_value_for(:ignore_frames, klass.base_class, false)
        klass.current_frame = saved_frame
      end

      # Converts a framed relation to one suitable for mutations.
      # CTEs cannot be mutated directly, so we convert frames to WHERE clauses on the base table.
      # Returns a new relation with:
      # - Frame conditions merged as WHERE clauses
      # - Base table name (not frame table name)
      # - No frame_clause (CTEs removed)
      def as_mutation_relation
        # Start with unframed to get a clean relation with base table
        # This removes frames but keeps default_scope
        relation = klass.unframed

        # Merge all WHERE conditions from frames
        frame_clause.frames.each_value do |frame_relation|
          relation = relation.merge(frame_relation.unscope(:select))
        end

        # Merge any additional WHERE conditions from the current relation
        # (conditions added after the frame was applied)
        if where_clause.any?
          relation = relation.merge(spawn.only(:where))
        end

        relation
      end

    end
  end
end
