case Gem::Version.new(Arel::VERSION)
when Gem::Requirement.new('>= 7.0')
  Arel::Table.class_eval do
    def engine
      type_caster.send(:types)
    end

    def engine=(value)
      @type_caster = value.type_caster
    end
  end

  Arel::Nodes::TableAlias.class_eval do
    def engine
      left.send(:type_caster)
    end
  end
else
  Arel::Table.class_eval do
    def engine=(value)
      @engine = value
    end
  end
end
