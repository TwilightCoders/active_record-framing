require 'spec_helper'

RSpec.describe 'Table name propagation in WHERE clauses' do
  before(:each) do
    User.delete_all
    Post.delete_all
  end

  describe 'named frames with WHERE clauses' do
    it 'uses the CTE table name in WHERE predicates' do
      sql = Post::Deleted.where(title: 'test').to_sql

      # Should use "deleted/documents" in both CTE and WHERE clause
      expect(sql).to include('WITH "deleted/documents" AS')
      expect(sql).to include('"deleted/documents"."title" = \'test\'')
      # Should NOT use base table "documents" in WHERE
      expect(sql).not_to match(/WHERE.*"documents"\."title"/)
    end

    it 'executes queries with correct table references' do
      # Should not raise PG::UndefinedTable error
      expect { Post::Deleted.where(title: 'test').to_a }.not_to raise_error
    end

    it 'handles chained WHERE clauses' do
      sql = Post::Deleted.where(title: 'test').where(scope: 1).to_sql

      # Both WHERE conditions should use deleted/documents
      expect(sql).to include('"deleted/documents"."title"')
      expect(sql).to include('"deleted/documents"."scope"')
    end
  end

  describe 'unframed table reset' do
    it 'resets table name back to base table' do
      # Named frame uses custom table name
      framed_table = Post::Deleted.table.name
      expect(framed_table).to eq('deleted/documents')

      # Unframed should reset to base table
      unframed_table = Post::Deleted.unframed.table.name
      expect(unframed_table).to eq('documents')
    end

    it 'uses base table name in WHERE after unframed' do
      sql = Post::Deleted.where(title: 'test').unframed.where(scope: 1).to_sql

      # WHERE clause created before unframed preserves its explicit table reference
      expect(sql).to include('"deleted/documents"."title"')
      # WHERE clause created after unframed uses base table
      expect(sql).to include('"documents"."scope"')
    end
  end

  describe 'default frames with WHERE clauses' do
    it 'uses the default frame CTE table name in WHERE' do
      sql = User.where(email: 'test@example.com').to_sql

      # Default frame creates "users" CTE
      expect(sql).to include('WITH "users" AS')
      expect(sql).to include('"users"."email" = \'test@example.com\'')
    end
  end

  describe 'spawned relations preserve table context' do
    it 'preserves table name through multiple where calls' do
      relation = Post::Deleted
        .where(title: 'a')
        .where(scope: 1)
        .where(user_id: 123)

      sql = relation.to_sql

      # All WHERE conditions in outer SELECT should reference deleted/documents
      expect(sql.scan(/"deleted\/documents"/).count).to be >= 3
      # CTE uses base table, but outer WHERE should use frame table
      # Extract the outer SELECT part (after the CTE closing paren)
      outer_select = sql.split(/\)\s+SELECT/).last
      expect(outer_select).to match(/"deleted\/documents"/)
      expect(outer_select).not_to match(/"documents"\./)
    end
  end
end
