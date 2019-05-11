require "spec_helper"

describe ActiveRecord::Framing do

  context 'when creating records' do
    it 'does not apply frames' do
      user = User.create!(name: 'bob')
      expect(user.kind).to_not eq(1)
    end
  end

  context 'when reframing' do
    it 'should return the properly framed and scoped records' do
      user = User.create(name: 'bob', kind: 1)
      post = Post.create(user: user, deleted_at: Time.now, scope: 1)

      4.times do
        Comment.create(post: post, user: user)
      end

      users = User.joins(posts: :comments).reframe(posts: Post::Deleted).distinct
      expect(users.length).to eq(1)
    end

    it 'should generate the correct SQL' do
      expect(User.joins(posts: :comments).reframe(posts: Post::Deleted).to_sql).to match_sql(<<~SQL)
        WITH
          "users" AS
            (SELECT "users".* FROM "users" WHERE "users"."kind" = 1),
          "deleted/documents" AS
            (SELECT "documents".* FROM "documents" WHERE \(?"documents"."deleted_at" IS NOT NULL\)?)
        SELECT "users".* FROM "users"
          INNER JOIN "deleted/documents" ON "deleted/documents"."user_id" = "users"."id" AND "deleted/documents"."scope" = 1
          INNER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id" WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end

    it 'should not apply the same reframe to subsequent relations' do
      decoy_sql = User.joins(posts: :comments).reframe(posts: Post::Deleted).to_sql
      expect(User.joins(posts: :comments).to_sql).to match_sql(<<~SQL)
        WITH
          "users" AS
            (SELECT "users".* FROM "users" WHERE "users"."kind" = 1),
          "documents" AS
            (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL)
        SELECT "users".* FROM "users"
          INNER JOIN "documents" ON "documents"."user_id" = "users"."id" AND "documents"."scope" = 1
          INNER JOIN "comments" ON "comments"."post_id" = "documents"."id" WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end

  end

    # # reframe no hash = apply default frame
    # expect(Post.joins(:user).reframe(:user).to_sql).to eq(<<~SQL.squish)
    #   WITH
    #     "documents" AS
    #       (SELECT "documents".* FROM "documents" WHERE "documents"."active_record-framing" IS NULL),
    #     "users" AS
    #       (SELECT "users".* FROM "users" WHERE "users"."active_record-framing" IS NULL)
    #   SELECT "documents".* FROM "documents"
    #     INNER JOIN "users" ON "users"."id" = "documents"."user_id"
    # SQL

    # # reframe hash symbol value = lookup frame by value and apply
    # expect(Post.joins(:user).reframe(user: :deleted).to_sql).to eq(<<~SQL.squish)
    #   WITH
    #     "documents" AS
    #       (SELECT "documents".* FROM "documents" WHERE "documents"."active_record-framing" IS NULL),
    #     "deleted/users" AS
    #       (SELECT "users".* FROM "users" WHERE active_record-framing IS NOT NULL)
    #   SELECT "documents".* FROM "documents"
    #     INNER JOIN "deleted/users" ON "deleted/users"."id" = "documents"."user_id"
    # SQL

    # # reframe hash frame/relation value = lookup frame by value and apply
    # expect(Post.joins(:user).reframe(user: User::Deleted).to_sql).to eq(<<~SQL)
    #   WITH "deleted/users" AS
    #     (SELECT "users".* FROM "users" WHERE active_record-framing IS NOT NULL)
    #   SELECT * FROM "documents"
    #     INNER JOIN "deleted/users" ON "deleted/users".id = "documents"."user_id"
    # SQL

    # # debatable???
    # # reframe hash with nil value = apply default frame
    # expect(Post.joins(:user).reframe(user: nil).to_sql).to eq(<<~SQL)
    #   WITH "users" AS
    #     (SELECT "users".* FROM "users" WHERE active_record-framing IS NULL)
    #   SELECT * FROM "documents"
    #     INNER JOIN "users" ON "users".id = "documents"."user_id"
    # SQL

    # expect(Post.joins(:user).unframe(:user).to_sql).to eq(<<~SQL)
    #   SELECT * FROM "documents"
    #     INNER JOIN "users" ON "users".id = "documents"."user_id"
    # SQL

    # expect(User::All.to_sql).to eq(<<~SQL)
    #   WITH "all/users" AS
    #     (SELECT "users".* FROM "users")
    #   SELECT * FROM "all/users"
    # SQL

    # expect(User::Deleted.to_sql).to eq(<<~SQL)
    #   WITH "deleted/users" AS
    #     (SELECT "users".* FROM "users" WHERE active_record-framing IS NOT NULL)
    #   SELECT * FROM "deleted/users"
    # SQL

    # expect(User.to_sql).to eq(<<~SQL)
    #   WITH "users" AS
    #     (SELECT "users".* FROM "users" WHERE active_record-framing IS NULL)
    #   SELECT * FROM "users"
    # SQL
end
