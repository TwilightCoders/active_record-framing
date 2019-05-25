require "spec_helper"

describe ActiveRecord::Framing do

  let!(:bob) { User.create(name: 'bob', kind: 1) }
  let!(:charlie) { User.create(name: 'charlie', kind: 1) }
  let!(:alice) { User.create(name: 'alice') }

  let!(:bob_posts) { 3.times.collect { |i|
    Post.create(user: bob, scope: i%2)
  }}

  let!(:bob_deleted_posts) { bob_posts.last(2).each { |p|
    p.update(deleted_at: Time.now)
  }}

  let!(:alice_posts) { 4.times.collect { |i|
    Post.create(user: alice, scope: i%2)
  }}

  let!(:alice_deleted_posts) { alice_posts.last(2).each { |p|
    p.update(deleted_at: Time.now)
  }}

  let!(:alice_comments) { bob_posts.each { |p|
    Comment.create(post: p, user: alice)
  }}

  let!(:bob_comments) { alice_posts.each { |p|
    Comment.create(post: p, user: bob)
  }}

  context 'when creating records' do
    it 'does not apply frames' do
      expect(bob.kind).to_not eq(1)
    end
  end

  context 'deep reframing' do
    it 'properly scopes' do
      $break = true
      expect(User::All.joins(posts: { comments: :votes }).joins(:votes).reframe(posts: { comments: { votes: Vote::Revoked } }).to_sql).to match_sql(<<~SQL)
        WITH "all/users" AS
          (SELECT "users".* FROM "users"),
        "revoked/votes" AS
          (SELECT "votes".* FROM "votes" WHERE "votes"."revoked" != FALSE),
        "documents" AS
          (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL)
        SELECT "all/users".* FROM "all/users"
          INNER JOIN "votes" ON "votes"."user_id" = "all/users"."id"
          INNER JOIN "documents" ON "documents"."user_id" = "all/users"."id" AND "documents"."scope" = 1
          INNER JOIN "comments" ON "comments"."document_id" = "documents"."id"
          INNER JOIN "revoked/votes" ON "revoked/votes"."comment_id" = "comments"."id"
      SQL
    end
  end

  context 'when reframing' do
    it 'should return the properly framed and scoped records' do
      query = User.joins(posts: :comments).reframe(posts: Post::Deleted).distinct
      expect(query.length).to eq(1)
    end

    it 'should return the correct records' do
      query = User.joins(posts: :comments).reframe(posts: Post::Deleted)
      binding.pry
      expect(query.count).to eq(1)
    end

    it 'should not apply the same reframe to subsequent relations' do
      decoy_query = User.joins(posts: :comments).reframe(posts: Post::Deleted)
      query = User.joins(posts: :comments)
      binding.pry
      expect(query).to match_sql(expected_sql)
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
