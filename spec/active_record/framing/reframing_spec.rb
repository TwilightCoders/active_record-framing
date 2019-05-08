

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
