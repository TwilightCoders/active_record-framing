module ActiveRecord
  module Framing
    module QueryMethods
      {
        frames: {},
        reframe: {}
      }.each do |value_name, default_value|
        define_method("#{value_name}_values") do
          @values[value_name] || default_value
        end
        define_method("#{value_name}_values=") do |values|
          raise ImmutableRelation if @loaded
          check_cached_relation
          @values[value_name] = values
        end
      end
    end
  end
end
