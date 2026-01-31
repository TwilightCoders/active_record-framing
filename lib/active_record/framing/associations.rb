module ActiveRecord
  module Framing
    module Associations
      def has_many(name, scope = nil, **options, &extension)
        super.tap do |reflections|
          reflections[name.to_s].klass.frames.each do |frame_name, frame|
            reflection = Builder::HasMany.build_with_frame(self, name, frame_name, options, &extension)
            Reflection.add_reflection self, name, reflection
            super("#{frame_name.downcase}_#{name}")
          end
        end
      end
    end
  end
end
