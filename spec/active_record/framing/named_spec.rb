require "spec_helper"

describe ActiveRecord::Framing::Named do

  it 'handles basic joins' do
    user_join = rx('"users"\."id" = "deleted/documents"\."user_id".*?"users"\."kind" = 1')

    expect(Post::Deleted.joins(:user, :comments).to_sql).to match_sql(<<~SQL)
      WITH "deleted/documents" AS (SELECT "documents".* FROM "documents" WHERE #{rx('.*?')}),
      "users" AS (SELECT "users".* FROM "users" WHERE #{rx('.*?')})
      SELECT "deleted/documents".* FROM "deleted/documents"
      INNER JOIN "users" ON #{user_join}
      INNER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
    SQL
  end

  it 'handles basic eager_loads' do
    sql = Post::Deleted.eager_load(:user, :comments).to_sql
    user_join = rx('"users"\."id" = "deleted/documents"\."user_id".*?"users"\."kind" = 1')

    expect(sql).to match_sql(<<~SQL)
      WITH "deleted/documents" AS (SELECT "documents".* FROM "documents" WHERE #{rx('.*?')}),
      "users" AS (SELECT "users".* FROM "users" WHERE #{rx('.*?')})
      SELECT #{rx('.*?')}
      FROM "deleted/documents"
      LEFT OUTER JOIN "users" ON #{user_join}
      LEFT OUTER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
    SQL
  end

  it 'presents the correct model class' do

    post = Post.create(title: 'hi', deleted_at: Time.now)

    expect(Post::Deleted.first.class).to eq(Post)

  end

  it 'warns if creating another frame by the same name' do
    expect(Post.logger).to receive(:warn).with("Creating frame :Test. Overwriting existing const Post::Test.")
    Post.class_eval do
      frame :test, -> {}
      frame :test, -> {}
    end
  end

  context '#unframed' do
    it 'does not employ CTE' do
      # unframed removes the frame (CTE) but keeps default_scope
      expect(User.unframed.to_sql).to match_sql(<<~SQL.squish)
        SELECT "users".* FROM "users" WHERE "users"."kind" = 1
      SQL
    end
  end

end
