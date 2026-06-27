# Arel::Table#engine was removed when Arel was absorbed into ActiveRecord.
# Framing reconstructs it from the table's type_caster, which exposes the
# model. That accessor was named `types`/`@types` originally and renamed
# `klass`/`@klass` (Rails 7.x), so probe for whichever this version uses.
case Gem::Version.new(Arel::VERSION)
when Gem::Requirement.new('>= 7.0')
  Arel::Table.class_eval do
    def engine
      tc = type_caster
      tc.respond_to?(:klass, true) ? tc.send(:klass) : tc.send(:types)
    end

    def engine=(value)
      ivar = @type_caster.instance_variable_defined?(:@klass) ? :@klass : :@types
      @type_caster.instance_variable_set(ivar, value)
    end
  end

  Arel::Nodes::TableAlias.class_eval do
    def engine
      tc = left.send(:type_caster)
      tc.respond_to?(:klass, true) ? tc.send(:klass) : tc.send(:types)
    end
  end
else
  Arel::Table.class_eval do
    def engine=(value)
      @engine = value
    end
  end
end
