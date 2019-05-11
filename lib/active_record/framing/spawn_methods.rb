module ActiveRecord
  module Framing
    module SpawnMethods

      def merge!(other) # :nodoc:
        super.tap do |rel|
          rel.frames_values = rel.frames_values.merge(other.frames_values)
        end
      end

    end
  end
end
