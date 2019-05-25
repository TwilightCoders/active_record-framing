class User < ::ActiveRecord::Base

  has_many :posts
  has_many :comments
  has_many :votes

  default_scope {
    where.not(kind: nil)
  }

  default_frame {
    where(arel_table[:kind].eq(1))
    # where(kind: 1)
  }

  frame :all, -> {}

  # Clearly wont work with other frames, but hardcoded SQL is never recommended.
  scope :custom_scope, -> { joins("INNER JOIN posts ON posts.user_id = users.id") }
end
