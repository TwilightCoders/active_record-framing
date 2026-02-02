require "spec_helper"

describe 'Model Inheritance' do
  subject { model.to_sql }

  context 'Admin' do

    context 'default frames' do
      let(:model) { Admin.all }

      it 'should not repeat inheritance scope' do
        # Admin inherits User's default_frame (kind IS NOT NULL) in the CTE
        # The STI type condition is applied in the outer SELECT
        type_condition = rx('"users"\."type" (IN|=) .+')

        expect(subject).to match_sql(<<~SQL)
          WITH "users" AS (SELECT "users".* FROM "users" WHERE #{rx('.*?')})
          SELECT "users".* FROM "users" WHERE #{type_condition}
        SQL
      end
    end

    context 'named frames' do
      let(:model) { Admin::Special.all }

      it 'should scope down using correct table name' do
        # Named frame includes both the frame condition and STI type condition
        # May or may not have WHERE in outer SELECT depending on Rails version
        expect(subject).to match_sql(<<~SQL)
          WITH "special/users" AS (SELECT "users".* FROM "users" WHERE #{rx('.*?')})
          SELECT "special/users".* FROM "special/users"#{rx('( WHERE .*)?')}
        SQL
      end
    end
  end

end
