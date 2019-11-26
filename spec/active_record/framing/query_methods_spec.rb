require "spec_helper"

describe ActiveRecord::Framing::QueryMethods do

  [:joins, :preload, :eager_load].each do |method|
    context "when ##{method} is used" do
      it 'returns the proper count' do
        # Previous code erroneously merged in where clauses from frames
        # that would get carried over in a count operation.
        # This proved particularly problematic for

        user = User.create(name: 'foo', kind: 1)
        admin = Admin.create(name: 'foo', kind: 2)
        post = Post.create(title: 'hi', user: user, deleted_at: Time.now)
        comment = Comment.create(post: post, user: admin)

        count = log_sql do
          Post::Deleted.send(method, :user, :admin_commenters, :comments).count
        end
        expect(count).to eq(1)
      end

    end
  end

  it 'handles basic joins' do
    expect(Post::Deleted.joins(:user, :comments).to_sql).to match_sql(<<~SQL)
      WITH
        "deleted/documents" AS
          (SELECT "documents".* FROM "documents" WHERE \(?"documents"."deleted_at" IS NOT NULL\)?),
        "users" AS
          (SELECT "users".* FROM "users" WHERE "users"."type" IN ('Admin') AND "users"."kind" = 1)
      SELECT "deleted/documents".* FROM "deleted/documents"
        INNER JOIN "users" ON "users"."id" = "deleted/documents"."user_id" AND \(?"users"."kind" IS NOT NULL\)?
        INNER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
    SQL
  end

  context '.from' do
    xit 'should collect the frames from the other query' do
      user = User.create(name: 'bob', type: 'User')
      post = Post.create(user: user, deleted_at: Time.now, scope: 1)

      4.times do
        Comment.create(post: post, user: user)
      end


      inner = User.where(name: 'bob')
      outer = User.where(type: 'Admin').from(inner)

      sql = outer.to_sql
      expect(sql).to match_sql(<<~SQL)
        WITH "users" AS
        (SELECT "users".* FROM "users" WHERE "users"."type" = 'User')
        SELECT "users".* FROM
          (SELECT "users".* FROM "users" WHERE "users"."type" IS NOT NULL AND "users"."name" = 'bob')
          subquery WHERE "users"."type" IS NOT NULL AND "users"."type" = 'Admin'
      SQL
    end
  end

  context '.frame' do
    xit 'should frame the association' do
      $pry = true
      query = Post.all.frame(Post::Deleted)
      Post::Deleted === ActiveRecord::Base
      sql = query.to_sql
      expect(sql).to match_sql(<<~SQL)
        WITH "users" AS
        (SELECT "users".* FROM "users" WHERE "users"."type" = 1)
        SELECT "users".* FROM
          (SELECT "users".* FROM "users" WHERE "users"."type" IS NOT NULL AND "users"."name" = 'bob')
          subquery WHERE "users"."type" IS NOT NULL AND "users"."type" = 2
      SQL
    end
  end
end
