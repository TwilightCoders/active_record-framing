# Arel::Table engine accessor compatibility
#
# In Arel 7+ (Rails 5.1+), Arel::Table stores the "engine" (model class)
# inside its type_caster, not as a direct @engine attribute.
# We need an engine= setter for reframing JOINs.
#
# In Rails 7.0+, Arel is vendored into ActiveRecord and doesn't have
# its own VERSION constant.

arel_version = if defined?(Arel::VERSION)
  Gem::Version.new(Arel::VERSION)
else
  # Arel vendored into AR — use AR version as proxy
  Gem::Version.new(ActiveRecord.version.to_s)
end

if arel_version >= Gem::Version.new('7.0')
  Arel::Table.class_eval do
    def engine
      if type_caster.respond_to?(:send, true)
        type_caster.send(:types) rescue nil
      end
    end

    def engine=(value)
      if @type_caster.respond_to?(:instance_variable_set)
        @type_caster.instance_variable_set(:@types, value)
      end
    end
  end

  Arel::Nodes::TableAlias.class_eval do
    def engine
      if left.respond_to?(:type_caster, true)
        left.send(:type_caster).send(:types) rescue nil
      end
    end
  end
else
  Arel::Table.class_eval do
    def engine=(value)
      @engine = value
    end
  end
end
