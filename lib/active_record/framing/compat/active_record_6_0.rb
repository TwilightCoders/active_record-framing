{
  frames: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH,
  reframe: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH
}.each do |value_name, default_value|
  ::ActiveRecord::Relation::DEFAULT_VALUES[value_name] = default_value
  define_method("#{value_name}_values") do   # def frames_values
    default = DEFAULT_VALUES[value_name]     #   default = DEFAULT_VALUES[:frames]
    @values.fetch(value_name, default)       #   @values.fetch(:frames, default)
  end                                        # end

  define_method("#{value_name}_values=") do |value| # def frames_values=(value)
    assert_mutability!                              #   assert_mutability!
    @values[value_name] = value                     #   @values[:frames] = value
  end                                               # end
end
