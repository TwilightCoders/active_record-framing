require 'delegate'

module ActiveRecord
  module Framing
    module Named

      DANGEROUS_FRAME_NAMES = [].freeze

      def dangerous_frame_name?(name)
        DANGEROUS_FRAME_NAMES.include?(name.to_sym)
      end

      def all(*)
        if (cf = current_frame)
          ignore_type_condition do
            unframed_all.merge!(cf)
          end
        else
          default_framed
        end
      end

      def relation_without_type_condition
        (@relation_without_type_condition ||= ignore_type_condition { relation.freeze }).dup
      end

      def relation_with_default_scope
        klass = (self < ActiveRecord::Base && base_class != self) ? base_class : self
        klass.unscoped.spawn
      end

      def ignore_type_condition
        old, @finder_needs_type_condition = @finder_needs_type_condition, :false
        yield
      ensure
        @finder_needs_type_condition = old
      end

      def scope_for_association(scope = relation_without_type_condition)
        ignore_type_condition do
          unframed_scope_for_association(scope).merge(current_frame || default_framed)
        end
      end

      def default_framed
        build_default_frame(relation_with_default_scope) || unframed_all
      end

      def frames
        @frames ||= {}
      end

      def frame(frame_name, body = nil, &block)
        constant = frame_name.to_s.classify.to_sym

        if dangerous_class_const?(constant)
          raise ArgumentError, "Frame name \"#{constant}\" conflicts with an existing constant on #{self.name}"
        end

        if dangerous_frame_name?(frame_name)
          raise ArgumentError, "Frame name :#{frame_name} is reserved"
        end

        if frames.key?(constant) && logger
          logger.warn "Overwriting existing frame #{self.name}::#{constant}"
        end

        arel_tn = "#{frame_name}/#{table_name}"
        at = arel_table.clone.tap { |t| t.name = arel_tn }

        frames[constant] = Proc.new do
          build_frame([body].compact, at, relation, &block)
        end
      end
    end
  end
end
