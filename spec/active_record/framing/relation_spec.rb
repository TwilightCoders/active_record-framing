require "spec_helper"

describe ActiveRecord::Framing::Relation do

  context 'model with custom scope' do

    it 'disregards when reflecting on join associations' do
      expect(User.custom_scope.to_sql).to match_sql(<<~SQL)
        WITH
          "users" AS
            (SELECT "users".* FROM "users" WHERE \(?"users"."kind" = 1\)?)
        SELECT "users".* FROM "users"
        INNER JOIN posts ON posts.user_id = users.id WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end

  end

  context 'given a default frame' do
    it 'handles a simple select' do
      expect(User.all.to_sql).to match_sql(<<~SQL)
        WITH
          "users" AS
            (SELECT "users".* FROM "users" WHERE \(?"users"."kind" = 1\)?)
        SELECT "users".* FROM "users" WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end

    it 'handles a join on a model with no default frame' do
      expect(User.joins(:comments).to_sql).to match_sql(<<~SQL)
        WITH
          "users" AS
            (SELECT "users".* FROM "users" WHERE \(?"users"."kind" = 1\)?)
        SELECT "users".* FROM "users"
          INNER JOIN "comments" ON "comments"."user_id" = "users"."id" WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end

    it 'handles a join on a model with a default frame' do
      expect(User.joins(:posts).to_sql).to match_sql(<<~SQL)
        WITH
          "users" AS
            (SELECT "users".* FROM "users" WHERE \(?"users"."kind" = 1\)?),
          "documents" AS
            (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL)
        SELECT "users".* FROM "users"
          INNER JOIN "documents" ON "documents"."user_id" = "users"."id" AND "documents"."scope" = 1 WHERE \(?"users"."kind" IS NOT NULL\)?
      SQL
    end
  end

  context 'given a named frame' do
    it 'handles a simple select' do
      expect(User::All.all.to_sql).to match_sql(<<~SQL)
        WITH "all/users" AS
          (SELECT "users".* FROM "users")
        SELECT "all/users".* FROM "all/users"
      SQL
    end

    it 'handles a join on a model with no default frame' do
      expect(User::All.joins(:comments).to_sql).to match_sql(<<~SQL)
        WITH "all/users" AS
          (SELECT "users".* FROM "users")
        SELECT "all/users".* FROM "all/users"
          INNER JOIN "comments" ON "comments"."user_id" = "all/users"."id"
      SQL
    end

    it 'handles a join on a model with a default frame' do
      expect(User::All.joins(:posts).to_sql).to match_sql(<<~SQL)
        WITH "all/users" AS
          (SELECT "users".* FROM "users"),
        "documents" AS
          (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL)
        SELECT "all/users".* FROM "all/users"
          INNER JOIN "documents" ON "documents"."user_id" = "all/users"."id" AND "documents"."scope" = 1
      SQL
    end
  end

end
