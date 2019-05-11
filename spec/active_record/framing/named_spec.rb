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
        INNER JOIN "users" ON "users"."id" = "deleted/documents"."user_id" AND \(?"users"."kind" IS NOT NULL\)?
        INNER JOIN "comments" ON "comments"."post_id" = "deleted/documents"."id"
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
