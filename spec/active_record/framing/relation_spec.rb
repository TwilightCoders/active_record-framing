require "spec_helper"

describe ActiveRecord::Framing::Relation do

  it 'also does these sql' do

    User.class_eval do

      frame :all, -> {}
      frame :deleted, -> { where.not(deleted_at: nil) }

      scope :foo, -> { where(1) }
      scope :foo, -> { where(2) }

    end

    Post.class_eval do
      default_frame {
        where(deleted_at: nil)
      }
    end

    expect(User.joins(:posts).to_sql).to eq(<<~SQL.squish)
      WITH "users" AS
        (SELECT "users".* FROM "users" WHERE "users"."deleted_at" IS NULL),
      "documents" AS
        (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL)
      SELECT "users".* FROM "users"
        INNER JOIN "documents" ON "documents"."user_id" = "users"."id"
    SQL

    binding.pry
    expect(User::All.joins(:posts).to_sql).to eq(<<~SQL.squish)
      WITH "all/users" AS
        (SELECT "users".* FROM "users"),
      "documents" AS
        (SELECT "documents".* FROM "documents")
      SELECT * FROM "all/users"
          INNER JOIN "documents" ON "documents".user_id = "all/users"."id"
    SQL

    expect(Document.joins(:user).to_sql).to eq(<<~SQL.squish)
      WITH "users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NULL)
      SELECT * FROM "documents"
          INNER JOIN "users" ON "users".id = "documents"."user_id"
    SQL

    # reframe no hash = apply default frame
    expect(Document.joins(:user).reframe(:user).to_sql).to eq(<<~SQL.squish)
      WITH "users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NULL)
      SELECT * FROM "documents"
        INNER JOIN "users" ON "users".id = "documents"."user_id"
    SQL

    # reframe hash symbol value = lookup frame by value and apply
    expect(Document.joins(:user).reframe(user: :deleted).to_sql).to eq(<<~SQL.squish)
      WITH "deleted/users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NOT NULL)
      SELECT * FROM "documents"
        INNER JOIN "deleted/users" ON "deleted/users".id = "documents"."user_id"
    SQL

    # reframe hash frame/relation value = lookup frame by value and apply
    expect(Document.joins(:user).reframe(user: User::Deleted).to_sql).to eq(<<~SQL)
      WITH "deleted/users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NOT NULL)
      SELECT * FROM "documents"
        INNER JOIN "deleted/users" ON "deleted/users".id = "documents"."user_id"
    SQL

    # debatable???
    # reframe hash with nil value = apply default frame
    expect(Document.joins(:user).reframe(user: nil).to_sql).to eq(<<~SQL)
      WITH "users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NULL)
      SELECT * FROM "documents"
        INNER JOIN "users" ON "users".id = "documents"."user_id"
    SQL

    expect(Document.joins(:user).unframe(:user).to_sql).to eq(<<~SQL)
      SELECT * FROM "documents"
        INNER JOIN "users" ON "users".id = "documents"."user_id"
    SQL

    expect(User::All.to_sql).to eq(<<~SQL)
      WITH "all/users" AS
        (SELECT "users".* FROM "users")
      SELECT * FROM "all/users"
    SQL

    expect(User::Deleted.to_sql).to eq(<<~SQL)
      WITH "deleted/users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NOT NULL)
      SELECT * FROM "deleted/users"
    SQL

    expect(User.to_sql).to eq(<<~SQL)
      WITH "users" AS
        (SELECT "users".* FROM "users" WHERE deleted_at IS NULL)
      SELECT * FROM "users"
    SQL

  end
end
