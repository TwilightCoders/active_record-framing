require "spec_helper"

describe ActiveRecord::Framing::Relation do

  it 'handles default scopes' do

    User.create(name: 'foo', kind: 1)

    user = User.first

    expect(user.posts.to_sql).to eq(<<~SQL.squish)
      WITH
        "documents" AS
          (SELECT "documents".* FROM "documents" WHERE "documents"."deleted_at" IS NULL)
      SELECT "documents".* FROM "documents" WHERE "documents"."scope" = 1 AND "documents"."user_id" = 1
    SQL

  end
end
