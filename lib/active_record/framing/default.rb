# frozen_string_literal: true

module ActiveRecord
  module Framing
    module Default
      extend ActiveSupport::Concern

      included do
        class_attribute :default_frames,
          instance_writer: false,
          instance_predicate: false

        self.default_frames = []
      end

      module ClassMethods
        def unframed(&block)
          unframed_all.unframed(&block)
        end

        def ignore_frames?
          FrameRegistry.value_for(:ignore_frames, base_class)
        end

        def evaluate_default_frame
          return if ignore_frames?
          self.ignore_frames = true
          yield
        ensure
          self.ignore_frames = false
        end

        # Scopes should be built without the default frame
        def evaluate_default_scope(*)
          evaluate_default_frame { super }
        end

        def default_arel_table
          @default_arel_table ||= arel_table.dup.tap { |at| at.name = sovereign_table_name }
        end

      protected

        def build_frame(frames, arel_table, base_rel = nil, &block)
          cte_relation = frames.inject(base_rel.clone) do |collection, frame|
            frame = frame.respond_to?(:to_proc) ? frame : frame.method(:call)
            frame_relation = collection.instance_exec(&frame)
            collection.merge!(frame_relation || base_rel)
          end

          frame_clause = FrameClause.new({ arel_table => cte_relation })

          relation.spawn.tap do |rel|
            rel.frame_clause = frame_clause
            rel.table = arel_table
            extension = Module.new(&block) if block_given?
            rel.extending!(extension) if extension
          end
        end

        def default_frame_override?
          return @default_frame_override if defined?(@default_frame_override)
          owner = method(:default_frame).owner
          # Only true if the model defines its own default_frame method
          # (not the DSL-generated one from Default::ClassMethods)
          @default_frame_override = owner != ActiveRecord::Framing::Default::ClassMethods &&
                                    !owner.is_a?(Class) # not Base or any AR class
        end

      private

        def ignore_frames=(value)
          FrameRegistry.set_value_for(:ignore_frames, base_class, value)
        end

        def default_frame(frame_name = nil, &frame)
          if default_frame_override?
            warn "default_frame method on #{method(:default_frame).owner} will be overridden by this block"
          end
          self.default_frames += [frame]
        end

        def sovereign_table_name
          if superclass < ::ActiveRecord::Base && table_name == superclass.table_name
            begin
              orig = superclass.abstract_class
              superclass.abstract_class = true
              return table_name
            ensure
              superclass.abstract_class = orig
            end
          end
          table_name
        end

        def build_default_frame(base_rel = nil)
          return if abstract_class?
          return if ignore_frames?
          return if ActiveRecord::Framing.disabled?

          frames_to_build = if default_frame_override?
            [method(:default_frame)]
          else
            default_frames
          end

          return unless frames_to_build.any?

          evaluate_default_frame do
            build_frame(frames_to_build, default_arel_table, base_rel || relation_with_default_scope)
          end
        end
      end
    end
  end
end
