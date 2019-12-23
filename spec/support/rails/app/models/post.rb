class Post < ::ActiveRecord::Base
  self.table_name = "documents"

  default_frame {
    where(deleted_at: nil)
  }

  puts "after default_frame"
  frame :deleted, -> {
    where.not(deleted_at: nil)
  }

  puts "after frame :deleted"

  default_scope {
    where(scope: 1)
  }
  puts "after default_scope"

  # Explicitely have associations after named frames.
  # Tests for the subclasses keeping in sync with the
  # parent classes (named.rb)
  belongs_to :user

  has_many :comments
  has_many :commenters, through: :comments, source: :user
  has_many :admin_commenters, through: :comments, source: :admin

  # Keep this because it tests whether AR:F too eagerly inspects
  # all of a class's associations
  has_many :non_existant_things

end
