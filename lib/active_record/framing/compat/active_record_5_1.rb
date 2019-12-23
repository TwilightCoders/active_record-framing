module ActiveRecord
  module Framing
    module QueryMethods
      {
        frames: ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH,
        reframe: ::ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH
      }.each do |value_name, default_value|
        define_method("#{value_name}_values") do
          get_value(value_name)
        end
        define_method("#{value_name}_values=") do |value|
          set_value(value_name, value)
        end
        ::ActiveRecord::QueryMethods::DEFAULT_VALUES[value_name] = default_value
      end
    end
  end
end
