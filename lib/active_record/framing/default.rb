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

        class_attribute :default_frame_override,
          instance_writer: false,
          instance_predicate: false

        self.default_frames = []
        self.default_frame_override = nil
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
        def unframed
          block_given? ? unframed_all.framing { yield } : unframed_all
        end

        def ignore_default_frame?
          FrameRegistry.value_for(:ignore_default_frame, base_class)
        end

        # The ignore_default_frame flag is used to prevent an infinite recursion
        # situation where a default frame references a frame which has a default
        # frame which references a frame...
        def evaluate_default_frame
          return if ignore_default_frame?
          self.ignore_default_frame = true
          yield
        ensure
          self.ignore_default_frame = false
        end

        def default_arel_table
          @default_arel_table ||= arel_table.dup.tap do |at|
            at.name = sovereign_table_name
          end
          # @default_arel_table ||= arel_table.alias(sovereign_table_name)
        end

      protected

        def build_frame(frames, arel_table, base_rel = nil, &block)
          cte_relation = frames.inject(base_rel.clone) do |collection, frame|
            frame = frame.respond_to?(:to_proc) ? frame : frame.method(:call)
            # Exec the frame, or grab the default_frame (by calling relation)
            frame_relation = base_rel.instance_exec(&frame)
            collection.merge!(frame_relation || base_rel)
          end

          # This turns off the STI condition clause outside of the frames
          # doit = finder_needs_type_condition? # gotta call this to init instance variable
          # orig, @finder_needs_type_condition = @finder_needs_type_condition, :false
          ignore_type_condition do
            relation.frame!(Arel::Nodes::As.new(arel_table, cte_relation.arel)).tap do |rel|
              rel.table = arel_table
              extension = Module.new(&block) if block_given?
              rel.extending!(extension) if extension
            end
          end
        end

      private

        def ignore_default_frame=(ignore)
          FrameRegistry.set_value_for(:ignore_default_frame, base_class, ignore)
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
        def default_frame(frame_name = nil, frame: nil) # :doc:
          frame = Proc.new if block_given?

          if frame.is_a?(Relation) || !frame.respond_to?(:call)
            raise ArgumentError,
              "Support for calling #default_frame without a block is removed. For example instead " \
              "of `default_frame where(color: 'red')`, please use " \
              "`default_frame { where(color: 'red') }`. (Alternatively you can just redefine " \
              "self.default_frame.)"
          end

          # TODO: Include default_scopes?
          # frame(:unframed)

          # default_arel_table.tap do |at|
          #   at.name = frame_name
          # end if frame_name

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
          # compute_table_name
          table_name
        end

        def build_default_frame(base_rel = nil)
          return if abstract_class?

          if default_frame_override.nil?
            self.default_frame_override = !::ActiveRecord::Base.is_a?(method(:default_frame).owner)
          end

          if default_frame_override
            # The user has defined their own default frame method, so call that
            evaluate_default_frame do
              if (frame = default_frame)
                (base_rel ||= relation).frame!(frame)
              end
            end
          elsif default_frames.any?
            evaluate_default_frame do
              # cte_table = Arel::Table.new(table_name)
              cte_table = default_arel_table
              build_frame(default_frames, cte_table, base_rel || relation)
            end
          end
        end
      end
    end
  end
end
