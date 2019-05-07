class User < ::ActiveRecord::Base
  with_deleted_at

  has_many :posts
  has_many :comments

  scope :admins, -> {
    # select(arel_table[Arel.star], arel_table[:tableoid])#
    where(kind: 1)
  }

  default_frame { where(deleted_at: nil) }
end
