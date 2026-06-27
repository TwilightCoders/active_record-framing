# frozen_string_literal: true

module ActiveRecord
  module Framing
    module Default
      extend ActiveSupport::Concern

      included do
        # Stores the default frame for the class.
        class_attribute :default_frames,
          instance_writer: false,
          instance_predicate: false

        self.default_frames = []
      end

      module ClassMethods
        # Returns a frame for the model without the previously set frames.
        #
        #   class Post < ActiveRecord::Base
        #     def self.default_frame
        #       where(published: true)
        #     end
        #   end
        #
        #   Post.all                                  # Fires "WITH posts AS (SELECT * FROM posts WHERE published = true) SELECT * FROM posts"
        #   Post.unframed.all                         # Fires "SELECT * FROM posts"
        #   Post.where(published: false).unframed.all # Fires "SELECT * FROM posts"
        #
        # This method also accepts a block. All queries inside the block will
        # not use the previously set frames.
        #
        #   Post.unframed {
        #     Post.limit(10) # Fires "SELECT * FROM posts LIMIT 10"
        #   }
        def unframed(&block)
          # Delegate to instance method which properly clears frame_clause and resets table
          unframed_all.unframed(&block)
        end

        def ignore_frames?
          FrameRegistry.value_for(:ignore_frames, base_class)
        end

        # The ignore_frames flag is used to prevent an infinite recursion
        # situation where a default frame references a frame which has a default
        # frame which references a frame...
        def evaluate_default_frame
          return if ignore_frames?
          self.ignore_frames = true
          yield
        ensure
          self.ignore_frames = false
        end

        # Scopes (defualts) should be built/considered
        # without the default frame (they're combined later)
        def evaluate_default_scope(*)
          evaluate_default_frame do
            super
          end
        end

        def default_arel_table
          @default_arel_table ||= arel_table.dup.tap do |at|
            at.name = sovereign_table_name
          end
        end

      protected

        def build_frame(frames, arel_table, base_rel = nil, &block)
          cte_relation = frames.inject(base_rel.clone) do |collection, frame|
            frame = frame.respond_to?(:to_proc) ? frame : frame.method(:call)
            # Exec the frame, or grab the default_frame (by calling relation)

            frame_relation = collection.instance_exec(&frame)
            collection.merge!(frame_relation || base_rel)
          end

          # Store the Relation object itself in a FrameClause
          # This keeps bind values with the relation until the last possible moment
          # Use the arel_table object as the hash key (not its name string)
          frame_relation_hash = {arel_table => cte_relation}
          frame_clause = FrameClause.new(frame_relation_hash)

          # Use relation (not relation_without_type_condition) so type condition is applied
          # For STI, this ensures the child class's type condition is in the outer query
          relation.spawn.tap do |rel|
            rel.frame_clause = frame_clause
            rel.table = arel_table
            extension = Module.new(&block) if block_given?
            rel.extending!(extension) if extension
          end
        end

        def default_frame_override?
          :true == (@default_frame_override ||= !::ActiveRecord::Base.is_a?(method(:default_frame).owner) ? :true : :false)
        end

      private

        def ignore_frames=(value)
          FrameRegistry.set_value_for(:ignore_frames, base_class, value)
        end

        # Use this macro in your model to set a default frame for all operations on
        # the model.
        #
        #   class Article < ActiveRecord::Base
        #     default_frame { where(published: true) }
        #   end
        #
        #   Article.all # => # Fires "WITH articles AS (SELECT * FROM articles WHERE published = true) SELECT * FROM articles"
        #
        # The #default_frame is not applied while updating/creating/building a record.
        #
        #   Article.new.published    # => nil
        #   Article.create.published # => nil
        #   Article.first.update(name: 'A Tale of Two Cities').published # => nil
        #
        # (You can also pass any object which responds to +call+ to the
        # +default_frame+ macro, and it will be called when building the
        # default frame.)
        #
        # If you use multiple #default_frame declarations in your model then
        # they will be merged together:
        #
        #   class Article < ActiveRecord::Base
        #     default_frame { where(published: true) }
        #     default_frame { where(rating: 'G') }
        #   end
        #
        #   Article.all # => WITH articles AS (SELECT * FROM articles WHERE published = true AND rating = 'G') SELECT * FROM articles
        #
        # This is also the case with inheritance and module includes where the
        # parent or module defines a #default_frame and the child or including
        # class defines a second one.
        #
        # If you need to do more complex things with a default frame, you can
        # alternatively define it as a class method:
        #
        #   class Article < ActiveRecord::Base
        #     def self.default_frame
        #       # Should return a frame, you can call 'super' here etc.
        #     end
        #   end
        def default_frame(frame_name = nil, &frame) # :doc:

          if default_frame_override?
            warn <<~WARN
              There is a default_frame method defined on #{method(:default_frame).owner}
              which will be overridden as a result of this default frame block
            WARN
          end

          self.default_frames += [frame]
        end

        def sovereign_table_name
          # TODO: Use compute_table_name to disambiguate between users and admins
          if superclass < ::ActiveRecord::Base && table_name == superclass.table_name
            begin
              orig, superclass.abstract_class = superclass.abstract_class, true
              # return compute_table_name
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
            # The user has defined their own default frame method, so call that
            [method(:default_frame)]
          else
            default_frames
          end

          if frames_to_build.any?
            evaluate_default_frame do
              cte_table = default_arel_table
              base = base_rel || relation_with_default_scope
              build_frame(frames_to_build, cte_table, base)
            end
          end
        end
      end
    end
  end
end
