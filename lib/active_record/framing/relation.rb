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

      def initialize_copy(other)
        # binding.pry if other.table != table
        # binding.pry if other.klass != klass
        super.tap do |something|
          # puts "uhoh: #{something.table_name} vs #{other.table_name}" if something.table_name != other.table_name
        end
      end

      def build_arel(*)
        super.tap do |ar|
          unless ignore_default_frame?
            build_frames(ar)
            ar.with(*frames_values.values) if frames_values.any?
          end
        end
      end

      def table=(value)
        @table = value
        @klass.table = value
      end

      def table_name
        arel_table.name
      end

      def arel_table
        # puts "Calling #arel_table for #{engine.name}"
        # if self == unframed_all || ignore_default_frame?
        #   puts "Unframed"
        #   super
        # else
        #   puts "calling #table"
        #   table
        # end
        # ignore_default_frame? ? super : table
        table
      end

      # Oh boy. This is a doozy. Buckle up:
      # ActiveRecord, in it's `build_select` method, is inconsistant in how
      # it uses it's own internal API. It calls both klass and @class at different
      # points. Furthermore, it does not rely on it's own default delgation for
      # things like `arel_table`, which we're trying to override. Given that
      # (in this circumstance) @klass is only used to access `arel_table`, we're
      # gonna be "sneaky" and just temporarily replace @klass with self, to act as
      # the responder for `arel_table`.
      def build_select(*)
        old, @klass = @klass, self
        super
      ensure
        @klass = old
      end

      def aggregate_column(column_name)
        framing { super }
      end

      def build_joins(*)
        framing { super }
      end

      # def table
      #   if ignore_default_frame?
      #     @better_table ||= Arel::Table.new(super.name, klass)
      #   else
      #     klass.default_arel_table
      #   end
      # end

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
            source = reframe_values.fetch(join_class.table_name) { join_class.all }

            # case table
            # when Arel::Table
            #   table.name = source.table.name
            # when Arel::Nodes::TableAlias
            #   table.right = source.table.name
            # end
            frame!(source)
          else

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

      def moon_walk(tables, klass)
        tables.each do |table|


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
        previous, klass.current_frame = klass.current_frame, arel_table unless @delegate_to_klass
        yield
      ensure
        klass.current_frame = previous unless @delegate_to_klass
      end

      # def scoping
      #   framing { super }
      # end
    end
  end
end
