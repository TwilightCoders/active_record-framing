# frozen_string_literal: true

module ActiveRecord
  module Framing
    class Dependency# :nodoc:

      attr_accessor :associations, :relation

      def initialize(associations = {}, relation = nil)
        @associations = {}.merge(associations)
        @relation     = relation
      end

      def [](key)
        @associations[key] ||= Dependency.new
      end

      def []=(key, value)
        @associations[key] = value
      end

      def self.make_tree(associations)
        {}.tap do |hash|
          walk_tree associations, hash
        end
      end

      def self.walk_tree(associations, hash)
        case associations
        when Symbol, String
          hash.relation = associations
        when Array
          associations.each do |assoc|
            walk_tree assoc, hash
          end
        when Hash
          associations.each do |k, v|
            hash[k] ||= Dependency.new
            walk_tree(v, hash[k])
          end
        else
          hash.relation = associations
        end
        hash
      end

      def to_h
        {
          associations: @associations.inject(Hash.new) { |h, (k, v)| hash[k] = v&.to_h; hash },
          relation: relation
        }
      end

    end
  end
end
# [{:posts=>{:comments=>{:votes=>:foo}}}]
# walk_tree({:comments=>{:votes=>:foo}}, :posts)
