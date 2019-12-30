module ActiveRecord
  module Framing
    module QueryMethods
      {
        frames: 'ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH',
        reframe: 'ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH'
      }.each do |value_name, default_value|
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{value_name}_values                                                 # def frames_values
            @values.fetch(:#{value_name}, #{default_value})                        #   @values.fetch(:frames, FROZEN_EMPTY_HASH)
          end                                                                      # end

          def #{value_name}_values=(value)     # def frames_values=(value)
            assert_mutability!                 #   assert_mutability!
            @values[:#{value_name}] = value    #   @values[:frames] = value
          end                                  # end
        CODE
      end
    end
  end
end
