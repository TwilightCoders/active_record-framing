require 'delegate'

module ActiveRecord
  module Framing
    module Named

      DANGEROUS_FRAME_NAMES = [].freeze

      def dangerous_frame_name?(name)
        DANGEROUS_FRAME_NAMES.include?(name.to_sym)
      end

      def all
        if (cf = current_frame)
          ignore_type_condition do
            unframed_all.merge!(cf)
          end
        else
          default_framed
        end
      end

      def relation_without_type_condition
        (@relation_without_type_condition ||= ignore_type_condition do
          relation.freeze
        end).dup
      end

      def relation_with_default_scope
        klass_for_relation = (self < ActiveRecord::Base && base_class != self) ? base_class : self
        klass_for_relation.unscoped.spawn
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

      def default_framed(my_frame = relation_without_type_condition)
        build_default_frame(relation_with_default_scope) || unframed_all
      end

      def frames
        @frames ||= {}
      end

      def frame(frame_name, body = nil, &block)
        constant = frame_name.to_s.classify.to_sym

        if dangerous_class_const?(constant)
          raise ArgumentError, "You tried to define a frame named \"#{constant}\" " \
            "on the model \"#{self.name}\", but there is a constant already " \
            "defined with the same name."
        end

        if dangerous_frame_name?(frame_name)
          raise ArgumentError, "You tried to define a frame named :#{frame_name}, " \
            "but this conflicts with an ActiveRecord method. " \
            "Reserved names: #{DANGEROUS_FRAME_NAMES.join(', ')}"
        end

        valid_frame_name?(constant)

        arel_tn = "#{frame_name}/#{self.table_name}"

        at = arel_table.clone.tap do |a_t|
          a_t.name = arel_tn
        end

        frames[constant] = Proc.new do
          rel = relation
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
