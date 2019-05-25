{
  frames_values: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH,
  reframe_values: ::ActiveRecord::Relation::FROZEN_EMPTY_HASH
}.each do |method_name, default_value|
  ::ActiveRecord::Relation::DEFAULT_VALUES[method_name] = default_value
  class_eval <<-CODE, __FILE__, __LINE__ + 1
    def #{method_name}                   # def includes_values
      default = DEFAULT_VALUES[:#{name}] #   default = DEFAULT_VALUES[:includes]
      @values.fetch(:#{name}, default)   #   @values.fetch(:includes, default)
    end                                  # end

    def #{method_name}=(value)           # def includes_values=(value)
      assert_mutability!                 #   assert_mutability!
      @values[:#{name}] = value          #   @values[:includes] = value
    end                                  # end
  CODE
end
