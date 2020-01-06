require "spec_helper"

describe 'Model Inheritance' do
  subject { model.to_sql }

  context 'Admin' do

    context 'default frames' do
      let(:model) { Admin.all }

      it 'should not repeat inheritance scope' do
        expect(subject).to match_sql(<<~SQL)
          WITH "users" AS
            (SELECT "users".* FROM "users" WHERE \\((?"users"."kind" = 2)?|\\("users"."type" \\(IN|=\\) (?'Admin')?\\)| AND \\)+)
          SELECT "users".* FROM "users"
        SQL
      end
    end

    context 'named frames' do
      let(:model) { Admin::Special.all }

      it 'should scope down using correct table name' do
        expect(subject).to match_sql(<<~SQL)
          WITH "special/users" AS
            (SELECT "users".* FROM "users" WHERE \\("users"."email" = 'special.person@example.com'|"users"."type" \\(IN|=\\) (?'Admin')?| AND \\)+)
          SELECT "special/users".* FROM "special/users"
        SQL
      end
    end
  end

end
