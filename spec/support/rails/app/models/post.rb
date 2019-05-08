class Post < ::ActiveRecord::Base
  self.table_name = "documents"

  belongs_to :user
  has_many :comments

  default_frame {
    where(deleted_at: nil)
  }

  frame :deleted, -> {
    where.not(deleted_at: nil)
  }

  default_scope {
    where(scope: 1)
  }
end
