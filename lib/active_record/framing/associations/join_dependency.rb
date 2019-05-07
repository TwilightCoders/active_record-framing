module ActiveRecord
  module Framing
    module Associations
      module JoinDependency # :nodoc:
        def initialize(base, associations, joins)
          super
          # @alias_tracker = AliasTracker.create(base.connection, joins)
          # @alias_tracker.aliased_table_for(base.table_name, base.table_name) # Updates the count for base.table_name to 1
          # tree = self.class.make_tree associations
          # @join_root = JoinBase.new base, build(tree, base)
          # @join_root.children.each { |child| construct_tables! @join_root, child }
        end

        # def join_constraints(*)
        #   super.tap do |res|
        #     res.each do |info|
        #       info.joins.each do |join|

        #       end
        #     end
        #   end
        # end
      end
    end
  end
end
