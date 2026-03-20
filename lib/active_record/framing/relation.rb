require 'active_record/framing/model_proxy'

module ActiveRecord
  module Framing
    module Relation

      def initialize(klass, *args, **kwargs)
        super
        unless @klass.class == ModelProxy
          has_frames = frame_clause && !frame_clause.empty?
          table_to_use = (has_frames && @table) ? @table : arel_table
          @klass = ModelProxy.new(@klass, table_to_use)
          @table = table_to_use
        end
      end

      def build_arel(*)
        @klass.reframe_values = reframe_values

        previous_frames = {}
        reframe_values.each do |assoc_name, reframe_relation|
          if (assoc = klass.reflect_on_association(assoc_name))
            target_klass = assoc.klass
            previous_frames[target_klass] = target_klass.current_frame
            target_klass.current_frame = reframe_relation
          end
        end

        super.tap do |ar|
          unless ignore_frames?
            build_frames(ar)

            frame_clause.binds unless frame_clause.empty?

            if frame_clause.any?
              frame_ctes = frame_clause.to_arel_ctes
              ar.with(*frame_ctes)
            end
          end
        end
      ensure
        previous_frames&.each do |target_klass, previous_frame|
          target_klass.current_frame = previous_frame
        end
      end

      def all
        spawn
      end

      def table=(value)
        @table = value
        @klass.table = value
        if @predicate_builder
          table_metadata = ::ActiveRecord::TableMetadata.new(@klass, value)
          @predicate_builder.instance_variable_set(:@table, table_metadata)
        end
        @where_clause_factory = nil
      end

      def aggregate_column(column_name)
        framing { super }
      end

      def build_joins(*)
        framing { super }
      end

      def build_frames(manager)
        assocs = klass.reflect_on_all_associations.each_with_object({}) do |assoc, hash|
          hash[assoc.name] = assoc
        rescue NameError
        end

        reframe_by_table = convert_association_keys_to_table_names(reframe_values, assocs)

        manager.join_sources.each do |join_source|
          next unless join_source&.left&.respond_to?(:name)
          source_table = join_source.left
          if (join_class = derive_engine(source_table, assocs))
            reframe_source = reframe_by_table.fetch(join_class.table_name) { join_class.all }
            reframe_cte = frame_cte_for(reframe_source)
            frame!(reframe_cte)
          end
        end

        reframe_by_table.each_value do |relation|
          relation.frame_clause.frames.each do |cte_table, frame_relation|
            frame!(cte_table => frame_relation)
          end
        end
      end

      def convert_association_keys_to_table_names(reframe_vals, associations)
        reframe_vals.each_with_object({}) do |(key, value), result|
          if (assoc = associations[key])
            result[assoc.klass.table_name] = value
          else
            result[key] = value
          end
        end
      end

      def derive_engine(source_table, associations)
        if source_table.respond_to?(:engine) && source_table.engine == ::ActiveRecord::Base
          associations[source_table.name]
        elsif associations.key?(source_table.name.to_sym)
          associations[source_table.name.to_sym]&.klass
        end
      end

      def bound_attributes
        if ignore_frames? || frame_clause.empty?
          super
        else
          frame_clause.binds + super
        end
      end

      def framing(skip_default_frame: false, skip_inherited_frame: false)
        previous_frame = klass.current_frame(skip_inherited_frame: skip_inherited_frame) unless @delegate_to_klass

        relation_to_use = skip_default_frame ? spawn_without_frames : self

        if block_given?
          klass.current_frame = relation_to_use unless @delegate_to_klass
          yield
        else
          relation_to_use
        end
      ensure
        klass.current_frame = previous_frame unless @delegate_to_klass
      end

      def unframed(&block)
        framing(skip_default_frame: true, skip_inherited_frame: true, &block)
      end

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

      def spawn_without_frames
        saved_frame = klass.current_frame
        klass.current_frame = nil

        FrameRegistry.set_value_for(:ignore_frames, klass.base_class, true)
        result = spawn.tap do |r|
          r.frame_clause = FrameClause.new({})
          r.table = klass.unframed_arel_table
        end
        FrameRegistry.set_value_for(:ignore_frames, klass.base_class, false)

        result
      ensure
        klass.current_frame = saved_frame
      end

      def as_mutation_relation
        relation = klass.unframed

        frame_clause.frames.each_value do |frame_relation|
          relation = relation.merge(frame_relation.unscope(:select))
        end

        if where_clause.any?
          relation = relation.merge(spawn.only(:where))
        end

        relation
      end

    end
  end
end
