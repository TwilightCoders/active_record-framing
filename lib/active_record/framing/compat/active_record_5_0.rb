{
  frames: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH,
  reframe: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH
}.each do |value_name, default_value|
  define_method("#{value_name}_values") do
    @values[value_name] || default_value
  end
  define_method("#{value_name}_values=") do |values|
    assert_mutability!
    @values[value_name] = values
  end
end
