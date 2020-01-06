class Post < ::ActiveRecord::Base
  self.table_name = "documents"

  default_frame {
    where(arel_table[:deleted_at].eq(nil))
  }

  frame :deleted, -> {
    where(arel_table[:deleted_at].not_eq(nil))
  }

  default_scope {
    where(arel_table[:scope].eq(1))
  }

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
