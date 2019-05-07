# frozen_string_literal: true

module ActiveRecord
  module Framing
    module Default
      extend ActiveSupport::Concern

      included do
        # Stores the default frame for the class.
        class_attribute :default_frames, instance_writer: false, instance_predicate: false
        class_attribute :default_frame_override, instance_writer: false, instance_predicate: false

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
          block_given? ? relation.framing { yield } : relation
        end

        # Are there attributes associated with this frame?
        def frame_attributes? # :nodoc:
          super || default_frames.any? || respond_to?(:default_frame)
        end

        def before_remove_const #:nodoc:
          self.current_frame = nil
        end

        def ignore_default_frame?
          FrameRegistry.value_for(:ignore_default_frame, base_class)
        end

        private

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
          def default_frame(frame = nil) # :doc:
            frame = Proc.new if block_given?

            if frame.is_a?(Relation) || !frame.respond_to?(:call)
              raise ArgumentError,
                "Support for calling #default_frame without a block is removed. For example instead " \
                "of `default_frame where(color: 'red')`, please use " \
                "`default_frame { where(color: 'red') }`. (Alternatively you can just redefine " \
                "self.default_frame.)"
            end

            self.default_frames += [frame]
          end

          def build_default_frame(base_rel = nil)
            return if abstract_class?

            if default_frame_override.nil?
              self.default_frame_override = !Base.is_a?(method(:default_frame).owner)
            end

            if default_frame_override
              # The user has defined their own default frame method, so call that
              # evaluate_default_frame do
              #   if frame = default_frame
              #     (base_rel ||= relation).merge!(frame)
              #   end
              # end
              warn "come back to me!"
            elsif default_frames.any?
              # cte_table = arel_table
              cte_table = Arel::Table.new(table_name)

              evaluate_default_frame do
                # Create CTE here

                cte_relation = default_frames.inject(relation) do |default_frame, frame|
                  frame = frame.respond_to?(:to_proc) ? frame : frame.method(:call)
                  default_frame.merge!(relation.instance_exec(&frame))
                end

                base_rel ||= relation
                base_rel.frame!(Arel::Nodes::As.new(Arel::Table.new(table_name), cte_relation.arel))# if cte_relation
              end
            end
          end

          def ignore_default_frame=(ignore)
            FrameRegistry.set_value_for(:ignore_default_frame, base_class, ignore)
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
      end
    end
  end
end