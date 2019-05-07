require 'delegate'

module ActiveRecord
  # = Active Record \Named \Frames
  module Framing
    module Named
      extend ActiveSupport::Concern

      module ClassMethods
        # Returns an ActiveRecord::Relation frame object.
        #
        #   posts = Post.all
        #   posts.size # Fires "select count(*) from  posts" and returns the count
        #   posts.each {|p| puts p.name } # Fires "select * from posts" and loads post objects
        #
        #   fruits = Fruit.all
        #   fruits = fruits.where(color: 'red') if options[:red_only]
        #   fruits = fruits.limit(10) if limited?
        #
        # You can define a frame that applies to all finders using
        # {default_frame}[rdoc-ref:Framing::Default::ClassMethods#default_frame].
        # def all
        #   super.tap do |rel|
        #     if frame = framed_all
        #       rel.with(frame)
        #     end
        #   end
        # end

        # alias this method?, framed_all
        # def all
        #   # if current_scope
        #   #   current_scope.clone
        #   # else
        #   #   default_scoped
        #   # end
        #   if current_frame
        #     puts "#{name} has a current_frame: #{current_frame.to_sql}"
        #     super.frame(current_frame.clone)
        #   else
        #     puts "#{name} is using a default_frame: #{default_framed.to_sql}" if default_framed
        #     super.frame(default_framed)
        #   end
        # end

        def all
          framed_all(super)
        end

        def framed_all(rel)
          if current_frame = self.current_frame
            if self == current_frame.klass
              current_frame.clone
            else
              rel.merge!(current_frame)
            end
          else
            default_framed(rel)
          end
        end

        def const_missing(const_name)
          registered_frames[const_name]&.call() || super
        end

        def registered_frames
          @registered_frames ||= {}
        end

        def frame_for_association(frame = relation) # :nodoc:
          current_frame = self.current_frame

          if current_frame && current_frame.empty_frame?
            frame
          else
            default_framed(frame)
          end
        end

        # def default_framed(frame = relation) # :nodoc:
        def default_framed(frame = nil) # :nodoc:
          !ignore_default_frame? && build_default_frame(frame) || frame
        end

        # Adds a class method for retrieving and querying objects.
        # The method is intended to return an ActiveRecord::Relation
        # object, which is composable with other frames.
        # If it returns +nil+ or +false+, an
        # {all}[rdoc-ref:Framing::Named::ClassMethods#all] frame is returned instead.
        #
        # A \frame represents a narrowing of a database query, such as
        # <tt>where(color: :red).select('shirts.*').includes(:washing_instructions)</tt>.
        #
        #   class Shirt < ActiveRecord::Base
        #     frame :red, -> { where(color: 'red') }
        #     frame :dry_clean_only, -> { joins(:washing_instructions).where('washing_instructions.dry_clean_only = ?', true) }
        #   end
        #
        # The above calls to #frame define class methods <tt>Shirt.red</tt> and
        # <tt>Shirt::DryCleanOnly</tt>. <tt>Shirt::Red</tt>, in effect,
        # represents the query <tt>Shirt.where(color: 'red')</tt>.
        #
        # You should always pass a callable object to the frames defined
        # with #frame. This ensures that the frame is re-evaluated each
        # time it is called.
        #
        # Note that this is simply 'syntactic sugar' for defining an actual
        # class method:
        #
        #   class Shirt < ActiveRecord::Base
        #     def self.red
        #       where(color: 'red')
        #     end
        #   end
        #
        # Unlike <tt>Shirt.find(...)</tt>, however, the object returned by
        # <tt>Shirt.red</tt> is not an Array but an ActiveRecord::Relation,
        # which is composable with other frames; it resembles the association object
        # constructed by a {has_many}[rdoc-ref:Associations::ClassMethods#has_many]
        # declaration. For instance, you can invoke <tt>Shirt.red.first</tt>, <tt>Shirt.red.count</tt>,
        # <tt>Shirt.red.where(size: 'small')</tt>. Also, just as with the
        # association objects, named \frames act like an Array, implementing
        # Enumerable; <tt>Shirt.red.each(&block)</tt>, <tt>Shirt.red.first</tt>,
        # and <tt>Shirt.red.inject(memo, &block)</tt> all behave as if
        # <tt>Shirt.red</tt> really was an array.
        #
        # These named \frames are composable. For instance,
        # <tt>Shirt.red.dry_clean_only</tt> will produce all shirts that are
        # both red and dry clean only. Nested finds and calculations also work
        # with these compositions: <tt>Shirt.red.dry_clean_only.count</tt>
        # returns the number of garments for which these criteria obtain.
        # Similarly with <tt>Shirt.red.dry_clean_only.average(:thread_count)</tt>.
        #
        # All frames are available as class methods on the ActiveRecord::Base
        # descendant upon which the \frames were defined. But they are also
        # available to {has_many}[rdoc-ref:Associations::ClassMethods#has_many]
        # associations. If,
        #
        #   class Person < ActiveRecord::Base
        #     has_many :shirts
        #   end
        #
        # then <tt>elton.shirts.red.dry_clean_only</tt> will return all of
        # Elton's red, dry clean only shirts.
        #
        # \Named frames can also have extensions, just as with
        # {has_many}[rdoc-ref:Associations::ClassMethods#has_many] declarations:
        #
        #   class Shirt < ActiveRecord::Base
        #     frame :red, -> { where(color: 'red') } do
        #       def dom_id
        #         'red_shirts'
        #       end
        #     end
        #   end
        #
        # Frames cannot be used while creating/building a record.
        #
        #   class Article < ActiveRecord::Base
        #     frame :published, -> { where(published: true) }
        #   end
        #
        #   Article.published.new.published    # => nil
        #   Article.published.create.published # => nil
        #
        # \Class methods on your model are automatically available
        # on frames. Assuming the following setup:
        #
        #   class Article < ActiveRecord::Base
        #     frame :published, -> { where(published: true) }
        #     frame :featured, -> { where(featured: true) }
        #
        #     def self.latest_article
        #       order('published_at desc').first
        #     end
        #
        #     def self.titles
        #       pluck(:title)
        #     end
        #   end
        #
        # We are able to call the methods like this:
        #
        #   Article.published.featured.latest_article
        #   Article.featured.titles
        def frame(frame_name, body, &block)
          unless body.respond_to?(:call)
            raise ArgumentError, "The frame body needs to be callable."
          end

          constant = frame_name.to_s.classify.to_sym
          tn = "#{frame_name}/#{self.table_name}"

          the_frame = body.respond_to?(:to_proc) ? body : body.method(:call)
          cte_relation = relation.merge!(relation.instance_exec(&the_frame) || relation)

          # self.const_set constant, Class.new(DelegateClass(self)) do |klass|
          delegator = self.name.to_sym
          self.const_set(constant, self.dup).class_eval do |klass|
            extend SingleForwardable
            def_delegator delegator, :type_caster
            # def_delegator delegator, :table_name

            klass.default_frames = []

            klass.table_name = tn

            klass.current_frame = build_frame(cte_relation, &block)
          end

          if dangerous_class_const?(constant)
            raise ArgumentError, "You tried to define a frame named \"#{constant}\" " \
              "on the model \"#{self.constant}\", but Active Record already defined " \
              "a class method with the same name."
          end

        end

        def build_frame(frame, &block)
          extension = Module.new(&block) if block
          relation.frame!(Arel::Nodes::As.new(Arel::Table.new(table_name), frame.arel)).tap do |rel|
            rel.extending!(extension) if extension
          end
        end

        private

          def valid_frame_name?(name)
            if respond_to?(name, true) && logger
              logger.warn "Creating frame :#{name}. " \
                "Overwriting existing method #{self.name}.#{name}."
            end
          end
      end
    end
  end
end