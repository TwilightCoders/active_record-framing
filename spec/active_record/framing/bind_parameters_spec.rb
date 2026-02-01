require 'spec_helper'

RSpec.describe 'Bind parameter handling with prepared_statements=false' do
  before(:each) do
    User.delete_all
  end

  describe 'CTE bind substitution' do
    it 'substitutes bind values inline in CTE when prepared_statements=false' do
      # Test config has prepared_statements: false
      expect(User.connection.prepared_statements).to be false

      # Default frame has WHERE kind = ? which becomes $1 placeholder
      sql = User.all.to_sql

      # With prepared_statements=false, the $1 should be substituted to actual value
      # Should NOT have $1 placeholder
      expect(sql).not_to include('$1')
      # Should have actual value inline (kind = 1 from default_scope)
      expect(sql).to match(/"users"\."kind" = \d+/)
    end

    it 'executes queries without bind parameter errors' do
      # Should not raise PG::ProtocolViolation
      expect { User.count }.not_to raise_error
      expect { User.all.to_a }.not_to raise_error
      expect { User.first }.not_to raise_error
    end

    it 'handles aggregate queries' do
      User.create!(name: 'Test', email: 'test@example.com', kind: 1)

      expect { User.average(:kind) }.not_to raise_error
      expect { User.minimum(:kind) }.not_to raise_error
      expect { User.maximum(:kind) }.not_to raise_error
      expect { User.sum(:kind) }.not_to raise_error
    end

    it 'handles named frames with binds' do
      # Post::Deleted has WHERE deleted_at IS NOT NULL
      sql = Post::Deleted.to_sql

      # Should not have $1 placeholders
      expect(sql).not_to include('$1')
      expect { Post::Deleted.count }.not_to raise_error
    end
  end

  describe 'outer query bind handling' do
    it 'keeps outer WHERE clause binds working' do
      # The WHERE outside the CTE should still work
      sql = User.where(email: 'test@example.com').to_sql

      # Outer WHERE might still use $1 (that's normal)
      # Just verify it executes without error
      expect { User.where(email: 'test@example.com').to_a }.not_to raise_error
    end
  end
end
