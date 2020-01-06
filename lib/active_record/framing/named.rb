require 'delegate'

module ActiveRecord
  # = Active Record \Named \Frames
  module Framing
    module Named

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
      def all
        unframed_all.merge(current_frame || default_framed)
      end


      def all
        if current_frame = self.current_frame
          ignore_type_condition do
            unframed_all.merge!(current_frame)
          end
        else
          default_framed
        end
      end

      def relation_without_type_condition
        (@relation_without_type_condition ||= ignore_type_condition do
          relation.freeze
        end).dup # dup doesn't copy the 'frozen'
      end

      def relation_with_default_scope
        (@relation_with_default_scope ||= unframed_all.freeze).dup # dup doesn't copy the 'frozen'
      end

      # def relation_with_default_scope_and_without_type_condition
      #   (@relation_with_default_scope_and_without_type_condition ||= ignore_type_condition do
      #     unframed_all.freeze
      #   end).dup # dup doesn't copy the 'frozen'
      # end

      # def relation_without_default_scope_and_without_type_condition
      #   (@relation_with_default_scope_and_without_type_condition ||= ignore_type_condition do
      #     relation.freeze
      #   end).dup # dup doesn't copy the 'frozen'
      # end

      # def relation_with_type_condition_and_without_default_scope
      #   (@relation_with_type_condition_and_without_default_scope ||= relation.freeze).dup # dup doesn't copy the 'frozen'
      # end

      # Turns off the STI condition clause
      def ignore_type_condition
        old, @finder_needs_type_condition = @finder_needs_type_condition, :false
        yield
      ensure
        @finder_needs_type_condition = old
      end

      def ignore_default_scope
        old, self.ignore_default_scope = self.ignore_default_scope, true
        yield
      ensure
        self.ignore_default_scope = old
      end

      def scope_for_association(scope = relation_without_type_condition) # :nodoc:
        ignore_type_condition do
          unframed_scope_for_association(scope).merge(current_frame || default_framed)
        end
      end

      def default_framed(my_frame = relation_without_type_condition)
        build_default_frame(relation_with_default_scope) || unframed_all
      end

      def frames
        @frames ||= {}
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
      def frame(frame_name, body = nil, &block)
        constant = frame_name.to_s.classify.to_sym

        if dangerous_class_const?(constant)
          raise ArgumentError, "You tried to define a frame named \"#{constant}\" " \
            "on the model \"#{self.constant}\", but there is a constant already " \
            "defined with the same name."
        end

        valid_frame_name?(constant)

        arel_tn = "#{frame_name}/#{self.table_name}"

        # The interface for creating an arel_table changes between arel versions.
        # Ultimately, we just need a copy with it's "table name" changed.
        at = arel_table.clone.tap do |a_t|
          a_t.name = arel_tn
        end
        # at = Arel::Table.new(arel_tn, arel_table.engine)
        # at = Arel::Table.new(arel_tn, self)

        frames[constant] = Proc.new do
          # Prevents the type condition from being in the frame (CTE)
          rel = relation#_without_type_condition
          build_frame([body].compact, at, rel, &block)
        end
      end

      private

        def valid_frame_name?(name)
          if frames.key?(name) && logger
            logger.warn "Creating frame :#{name}. " \
              "Overwriting existing const #{self.name}::#{name}."
          end
        end
    end
  end
end
