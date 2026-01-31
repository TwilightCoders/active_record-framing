module ActiveRecord
  module Framing
    module SpawnMethods

      def merge!(other) # :nodoc:
        super.tap do |rel|
          rel.frame_values = rel.frame_values.merge(other.frame_values)
          rel.frame_bind_values = rel.frame_bind_values.merge(other.frame_bind_values)
        end
      end

    end
  end
end
