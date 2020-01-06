module ActiveRecord
  module Framing
    module SpawnMethods

      def merge!(other) # :nodoc:
        super.tap do |rel|
          rel.frames_values = rel.frames_values.merge(other.frames_values)
          # rel.flatten_where_clauses!
        end
      end

    end
  end
end
