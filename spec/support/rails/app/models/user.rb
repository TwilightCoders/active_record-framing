class User < ::ActiveRecord::Base

  has_many :posts
  has_many :comments

  default_scope {
    where(kind: 1)
  }

  default_frame {
    where.not(kind: nil)
  }

  frame :all, -> {}
end
