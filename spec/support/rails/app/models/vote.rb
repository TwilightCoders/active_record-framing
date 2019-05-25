class Vote < ::ActiveRecord::Base
  belongs_to :user
  belongs_to :comment

  self.primary_key = :id

  default_frame {
    where(arel_table[:revoked].eq(false))
  }

  frame :revoked, -> {
    where(arel_table[:revoked].not_eq(false))
  }
end
