require "spec_helper"

describe ActiveRecord::Framing::Named do

  it 'handles basic joins' do
    Post.class_eval do

      frame :deleted, -> {
        where.not(deleted_at: nil)
      }

    end

    User.class_eval do
      default_scope {
        where(kind: nil)
      }
    end

    relation = Post::Deleted.joins(:user, :comments)
    binding.pry

    expect(relation.to_sql).to eq(<<~SQL.squish)
      WITH "deleted/documents" AS
        (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL),
      "users" AS
        (SELECT "users".* FROM "users" WHERE "users"."deleted_at" IS NULL)
      SELECT "deleted/documents".* FROM "deleted/documents"
        INNER JOIN "users" ON "users"."id" = "deleted/documents"."user_id" AND "users"."kind" IS NULL
        INNER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
    SQL
  end

end
