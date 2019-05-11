{
  frames: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH,
  reframe: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH
}.each do |value_name, default_value|
  define_method("#{value_name}_values") do
    get_value(value_name)
  end
  define_method("#{value_name}_values=") do |value|
    set_value(value_name, value)
  end
  ::ActiveRecord::Relation::DEFAULT_VALUES[value_name] = default_value
end
