class Comment < ::ActiveRecord::Base
  belongs_to :user
  belongs_to :post

  belongs_to :admin, foreign_key: :user_id

  self.primary_key = :id
end
