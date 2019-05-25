class Comment < ::ActiveRecord::Base
  belongs_to :user
  belongs_to :post

  has_many :votes

  self.primary_key = :id
end
