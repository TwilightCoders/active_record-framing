require "spec_helper"

describe ActiveRecord::Framing::Relation do

  context "associations" do
    it 'should produce sql considering default frames and scopes' do
      User.create(name: 'foo', kind: 1)

      user = User.first
      sql = user.posts.to_sql
      expect(sql).to match_sql(<<~SQL)
        WITH "documents" AS
          (SELECT "documents".* FROM "documents" WHERE \(?("documents"."scope" = 1| AND |"documents"."deleted_at" IS NULL)+\)?)
        SELECT "documents".* FROM "documents" WHERE "documents"."user_id" = #{user.id}
      SQL

    end

    it 'should return the properly framed and scoped records' do
      user = User.create(name: 'bob')

      4.times do
        # NOTE: Adding "scope" due to default_scope on Post
        Post.create(user: user, scope: 1)
      end

      posts = user.posts
      user.posts.first.delete

      expect(user.posts.count).to eq(3)
    end

  end

  context 'has_many :through' do

    it 'derives the class name properly' do
      poster = User.create(name: 'bob')
      commenter = User.create(name: 'alice', kind: 1)

      post = Post.create(user: poster)

      4.times do
        Comment.create(post: post, user: commenter)
      end

      expect(post.commenters.to_sql).to match_sql(<<~SQL)
        WITH "users" AS
          (SELECT "users".* FROM "users" WHERE \(?("users"."kind" IS NOT NULL| AND |"users"."kind" = 1)+\)?
        SELECT "users".* FROM "users"
          INNER JOIN "comments" ON "users"."id" = "comments"."user_id" WHERE "comments"."post_id" = #{post.id}
      SQL

    end

  end

end
