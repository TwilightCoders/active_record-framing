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
          # TODO: Add :user back to test disambiguation between "WITH users" and "WITH admins" (in join)
          Post::Deleted.send(method, :admin_commenters, :comments).count
        end
        expect(count).to eq(1)
      end

    end
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
