require "spec_helper"

#
# FAQs
# Q: Do `default_scope`s affect associations?
# A: Yes
#
# Q:

describe ActiveRecord::Framing::Default do

  it 'handles basic joins' do
    Post.class_eval do

      default_frame {
        where(deleted_at: nil)
      }

    end

    User.class_eval do
      default_scope {
        where(kind: nil)
      }
    end

    relation = Post.joins(:user, :comments)
    binding.pry

    expect(relation.to_sql).to eq(<<~SQL.squish)
      WITH "documents" AS
        (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL),
      "users" AS
        (SELECT "users".* FROM "users" WHERE "users"."deleted_at" IS NULL)
      SELECT "documents".* FROM "documents"
        INNER JOIN "users" ON "users"."id" = "documents"."user_id" AND "users"."kind" IS NULL
        INNER JOIN "comments" ON "comments"."post_id" = "documents"."id"
    SQL
  end

  it 'works with other named frames' do

    Post.class_eval do

      default_frame {
        where(deleted_at: nil)
      }

    end

    temp = Post.joins(:user, :comments)

    User.class_eval do
      default_scope {
        where(kind: nil)
      }
    end

    binding.pry
    sql = Post.joins(:user, :comments).to_sql

    expect(Post.joins(:user, :comments).reframe(user: :deleted).merge(Comment.joins(:user).reframe(user: :all)).to_sql).to eq(<<~SQL.squish)
      WITH "deleted/users" AS (
        SELECT * FROM "users" WHERE deleted_at IS NOT NULL
      ),
      WITH "all/users" AS (
        SELECT * FROM "users"
      ),
      WITH "comments" AS (
        SELECT * FROM "comments" WHERE deleted_at IS NULL
      )
      SELECT "documents".* FROM "documents"
        INNER JOIN "deleted/users" ON "deleted/users".id = "documents"."user_id"
        INNER JOIN "comments" ON "comments".post_id = "documents"."id"
        INNER JOIN "all/users" ON "all/users".id = "comments"."user_id"
    SQL

    # TODO: Trace the location of where the join on users for comments is renamed to "users_comments"
    <<~SQL
      SELECT "documents".* FROM "documents"
      INNER JOIN "users" ON "users"."id" = "documents"."user_id"
      INNER JOIN "comments" ON "comments"."post_id" = "documents"."id" LEFT OUTER JOIN "users" "users_comments" ON "users_comments"."id" = "comments"."user_id"
    SQL

  end


  it 'has correct sql' do
    binding.pry

    expect(User.all.to_sql).to eq(<<~SQL.squish)
      WITH "users" AS
        (SELECT "users".* FROM "users" WHERE "users"."deleted_at" IS NULL)
      SELECT "users".* FROM "users"
    SQL
  end

  it 'has correct sql' do
    expect(System.joins(:users).to_sql).to eq(<<~SQL)
      WITH "users" AS (
        SELECT * FROM "users" WHERE deleted_at IS NULL
      ),
      WITH "systems" AS (
        SELECT * FROM "systems" WHERE deleted_at IS NULL
      )
      SELECT * FROM "systems"
        INNER JOIN "system_users" ON "system_users".system_id = "systems"."id"
        INNER JOIN "users" ON "users".id = "system_users"."user_id";
    SQL

    expect(System.first.users.to_sql).to eq(<<~SQL)
      WITH "users" AS (
        SELECT * FROM "users" WHERE deleted_at IS NULL
      ),
      SELECT * FROM "users"
        INNER JOIN "system_users" ON "system_users".user_id = "users"."id"
      WHERE "system_users".system_id = "05c49935-c0ed-48ce-aaa7-4c4d2a81be91";
    SQL

  end
end
