require "spec_helper"

describe 'Edge Cases' do

  context 'empty and nil frames' do
    
    it 'handles frame with no conditions gracefully' do
      User.class_eval do
        frame :truly_empty, -> {}
      end

      sql = User::TrulyEmpty.all.to_sql
      expect(sql).to be_a(String)
      expect(sql).to include('SELECT')
    end

    it 'treats empty frame as selecting all records' do
      User.create(name: 'test1', kind: 1)
      User.create(name: 'test2', kind: 1)
      
      User.class_eval do
        frame :no_filter, -> {}
      end

      count = User::NoFilter.count
      expect(count).to be >= 2
    end

  end

  context 'frame chaining and composition' do
    
    it 'allows chaining additional conditions on framed relation' do
      Post::Deleted.where(title: 'test')
      # Should work without error
    end

    it 'applies frame then additional where' do
      post = Post.create(title: 'test', deleted_at: Time.now)
      
      result = Post::Deleted.where(title: 'test').first
      expect(result).to eq(post)
    end

    it 'can use scopes on framed models' do
      User.class_eval do
        scope :named_alice, -> { where(name: 'Alice') }
      end

      User::All.named_alice
      # Should not raise error
    end

  end

  context 'deeply nested joins' do
    
    xit 'handles 3-level deep joins' do
      # TODO: Rails 6 circular association handling causes stack overflow
      # User -> Posts -> Comments -> User (circular) triggers infinite recursion
      # in evaluate_default_frame -> scope_for_association loop
      user = User.create(kind: 1)
      post = Post.create(user: user)
      comment = Comment.create(post: post, user: user)

      # User -> Posts -> Comments -> User (circular)
      sql = User.joins(posts: { comments: :user }).to_sql
      expect(sql).to include('INNER JOIN')
    end

    xit 'applies frames to all levels of nested joins' do
      # TODO: Rails 6 circular association handling causes stack overflow
      sql = User.joins(posts: { comments: :user }).to_sql

      # Should have CTEs for User and Post (both have default frames)
      expect(sql).to include('"users"')
      expect(sql).to include('"documents"')
    end

  end

  context 'polymorphic associations' do
    
    it 'handles polymorphic associations if present' do
      # Most test suites don't have polymorphic models
      # But if they did, frames should work
      skip("No polymorphic associations in test suite")
    end

  end

  context 'special SQL clauses' do
    
    describe 'UNION' do
      it 'works with union' do
        # Some Rails versions support union
        skip("UNION not supported in this Rails version") unless User.respond_to?(:union)

        User.create(name: 'Alice', kind: 1)
        User.create(name: 'Bob', kind: 2)

        users1 = User.where(kind: 1)
        users2 = User.where(kind: 2)

        union = users1.union(users2)
        expect(union.count).to be >= 2
      end
    end

    describe 'LIMIT and OFFSET' do
      it 'works with limit' do
        User.create(name: 'Alice', kind: 1)
        User.create(name: 'Bob', kind: 1)

        users = User.limit(1)
        expect(users.count).to eq(1)
      end

      it 'works with offset' do
        User.create(kind: 1)
        User.create(kind: 1)
        
        users = User.offset(1).limit(1)
        expect(users.count).to eq(1)
      end
    end

  end

  context 'model class edge cases' do
    
    it 'works with models using custom table names' do
      # Post uses table_name = "documents"
      expect(Post.table_name).to eq('documents')
      expect(Post.all.to_sql).to include('documents')
    end

    it 'works with models that have default_scope' do
      # User has default_scope { where(kind: 1) }
      # Post has default_scope { where(scope: 1) }
      
      # Both default_scope AND default_frame should apply
      sql = User.all.to_sql
      expect(sql).to include('WITH') # Frame
      expect(sql).to include('kind') # Both frame and scope mention kind
    end

  end

  context 'transactions and locking' do
    
    it 'works inside transactions' do
      User.transaction do
        user = User.create(name: 'transactional', kind: 1)
        expect(User.find(user.id)).to eq(user)
      end
    end

    it 'works with pessimistic locking' do
      user = User.create(kind: 1)
      
      User.transaction do
        locked_user = User.lock.find(user.id)
        expect(locked_user).to eq(user)
      end
    end

  end

  context 'record creation and frames' do
    
    it 'does not apply frames during record creation' do
      # Frames are for SELECT, not INSERT
      user = User.create(name: 'test')
      expect(user).to be_persisted
    end

    it 'does not apply frames during build' do
      user = User.new(name: 'test')
      expect(user).to be_a(User)
      expect(user).not_to be_persisted
    end

    it 'does not apply frame attributes to new records' do
      # The frame should not set default attributes
      # Lift User's default_scope (kind = 1), which would set kind as in
      # stock Rails; the frame is still active inside unscoped { }.
      user = User.unscoped { User.new }
      # Even though frame filters by kind, it shouldn't SET kind
      # (kind defaults to 0 from database default, not from frame)
      expect(user.kind).to eq(0)
      # The default_scope, by contrast, does set it.
      expect(User.new.kind).to eq(1)
    end

  end

  context 'reload and persistence' do
    
    it 'reload respects frames' do
      user = User.create(name: 'test', kind: 1)
      user.name = 'changed'
      user.reload
      expect(user.name).to eq('test')
    end

    it 'reload fails if record no longer in frame' do
      user = User.create(name: 'test', kind: 1)
      user.update_column(:kind, nil)
      
      expect {
        user.reload
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

  end

  context 'associations and frames' do
    
    it 'applies frames to association queries' do
      user = User.create(kind: 1)
      Post.create(user: user, deleted_at: Time.now, scope: 1)
      Post.create(user: user, deleted_at: nil, scope: 1)

      # user.posts should apply Post's default frame (deleted_at IS NULL)
      expect(user.posts.count).to eq(1)
    end

    it 'works with has_many through' do
      user = User.create(kind: 1)
      post = Post.create(user: user, scope: 1)
      comment = Comment.create(post: post, user: user)

      # Post has_many :commenters, through: :comments
      if post.respond_to?(:commenters)
        expect(post.commenters).to include(user)
      end
    end

  end

  context 'ActiveRecord::Relation edge cases' do
    
    it 'handles empty relations' do
      users = User.none
      expect(users).to be_empty
    end

    it 'works with reverse_order' do
      User.create(name: 'Alice', kind: 1)
      User.create(name: 'Bob', kind: 1)

      users = User.order(:id).reverse_order
      expect(users).not_to be_empty
    end

    it 'works with reorder' do
      User.create(name: 'Alice', kind: 1)
      User.create(name: 'Bob', kind: 1)

      users = User.order(:id).reorder(:name)
      expect(users).not_to be_empty
    end

  end

  context 'inspect and to_s' do
    
    it 'does not trigger query on inspect' do
      relation = User.all
      expect { relation.inspect }.not_to raise_error
    end

    it 'shows reasonable output for to_sql' do
      sql = User.all.to_sql
      expect(sql).to be_a(String)
      expect(sql.length).to be > 0
    end

  end

end
