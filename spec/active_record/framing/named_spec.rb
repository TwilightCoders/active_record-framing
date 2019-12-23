require "spec_helper"

describe ActiveRecord::Framing::Named do

  it 'handles basic joins' do
    expect(Post::Deleted.joins(:user, :comments).to_sql).to match_sql(<<~SQL)
      WITH
        "deleted/documents" AS
          (SELECT "documents".* FROM "documents" WHERE \(?"documents"."deleted_at" IS NOT NULL\)?),
        "users" AS
          (SELECT "users".* FROM "users" WHERE "users"."kind" = 1)
      SELECT "deleted/documents".* FROM "deleted/documents"
        INNER JOIN "users" ON (\(?("users"\."id" = "deleted\/documents"\."user_id"\)?|\(?"users"\."kind" IS NOT NULL\)?| AND ))+
        INNER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
    SQL
  end

  it 'handles basic eager_loads' do
    sql = Post::Deleted.eager_load(:user, :comments).to_sql
    expect(sql).to match_sql(<<~SQL)
      WITH
        "deleted/documents" AS
          (SELECT "documents".* FROM "documents" WHERE ("documents"."deleted_at" IS NOT NULL)),
        "users" AS
          (SELECT "users".* FROM "users" WHERE "users"."kind" = 1)
      SELECT "deleted/documents"."id" AS t\\d_r\\d,
             "deleted/documents"."user_id" AS t\\d_r\\d,
             "deleted/documents"."title" AS t\\d_r\\d,
             "deleted/documents"."version" AS t\\d_r\\d,
             "deleted/documents"."scope" AS t\\d_r\\d,
             "deleted/documents"."created_at" AS t\\d_r\\d,
             "deleted/documents"."updated_at" AS t\\d_r\\d,
             "deleted/documents"."deleted_at" AS t\\d_r\\d,
             "users"."id" AS t\\d_r\\d,
             "users"."type" AS t\\d_r\\d,
             "users"."name" AS t\\d_r\\d,
             "users"."email" AS t\\d_r\\d,
             "users"."kind" AS t\\d_r\\d,
             "users"."created_at" AS t\\d_r\\d,
             "users"."updated_at" AS t\\d_r\\d,
             "comments"."id" AS t\\d_r\\d,
             "comments"."title" AS t\\d_r\\d,
             "comments"."user_id" AS t\\d_r\\d,
             "comments"."post_id" AS t\\d_r\\d,
             "comments"."created_at" AS t\\d_r\\d,
             "comments"."updated_at" AS t\\d_r\\d
      FROM "deleted/documents"
      LEFT OUTER JOIN "users" ON (\(?("users"\."id" = "deleted\/documents"\."user_id"\)?|\(?"users"\."kind" IS NOT NULL\)?| AND ))+
      LEFT OUTER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
    SQL
  end

  it 'presents the correct model class' do

    post = Post.create(title: 'hi', deleted_at: Time.now)

    expect(Post::Deleted.first.class).to eq(Post)

  end

  context '#unframed' do
    it 'does not employ CTE' do
      expect(User.unframed.to_sql).to match_sql(<<~SQL.squish)
        SELECT "users".* FROM "users" WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end
  end

end
