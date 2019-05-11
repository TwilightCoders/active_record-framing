require "spec_helper"

describe ActiveRecord::Framing do

  xit 'should use the table_alias if given' do
    inner_query = User.where(User.arel_table[:name].eq('bob'))
    inner_at = inner_query.as('bobs')
    sql = User.select(inner_at[:name]).from(inner_query, 'bobs').to_sql

    expect(sql).to match(Regexp.new(<<~SQL.squish))
      WITH "users/present" AS
        \\(SELECT "users"\\.\\* FROM "users" WHERE "users"\\."deleted_at" IS NULL\\)
          SELECT bobs\\."name" FROM
          \\(SELECT "users/present"\\.\\* FROM "users/present" WHERE "users/present"\\."name" = 'bob'\\) bobs
    SQL
  end

  xit 'ensure projection is present' do
    inner_query = User.select(:name).where(name: 'bob')
    inner_at = inner_query.as('bobs')
    results = User.select(inner_at[:name]).from(inner_query, 'bobs')
    sql = results.to_sql

    expect(sql).to match(Regexp.new(<<~SQL.squish))
      WITH "users/present" AS
        \\(SELECT "users".\\* FROM "users" WHERE "users"."deleted_at" IS NULL\\)
          SELECT bobs."name" FROM
            \\(SELECT "users/present"."name" FROM "users/present" WHERE "users/present"."name" = \\$1\\) bobs
    SQL
  end

  xit 'should allow for deep nesting with deleted_at scope being maintained' do
    # inner_query = User.all.from(User.where(name: 'bob').from(Admin.where(name: 'john').arel, 'johns').arel.as('johns')).as('bobs')
    User.where(name: 'bob').as('foo')
    # So, here's the deal. Rails (ActiveRecord, or Arel more specifically) in it's infinite wisdom,
    # doesn't think to use the table name
    Admin.connection.unprepared_statement do
      inner_query = User.from(User.where(name: 'bob').merge(Admin.where(name: 'john')), 'users')
      inner = inner_query.as('admin_users')
      sql = User.select(inner[:name]).from(inner).to_sql
    end

    sql_regex = Regexp.new(<<~SQL.squish)
      WITH "users" AS \\(SELECT "users".\\* FROM "users" WHERE "users"."deleted_at" IS NULL\\)
      SELECT bobs."name" FROM
      \\(SELECT "users".* FROM
        \\(SELECT "users".* FROM
          \\(WITH "users" AS
            \\(SELECT "users"."id", "users"."kind" FROM "users" WHERE "users"."deleted_at" IS NULL\\)
              SELECT "users"."id", "users"."kind" FROM "users" WHERE "users"."kind" = 1 AND "users"."name" = 'bob'\\) johns
                WHERE "users"."name" = 'john'\\) bobs_not_johns\\) bobs
    SQL

    expect(sql).to match(sql_regex)
  end

end
