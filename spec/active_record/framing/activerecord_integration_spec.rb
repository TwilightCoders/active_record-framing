require "spec_helper"

describe 'ActiveRecord Method Integration' do

  before do
    @user = User.create(name: 'Alice', kind: 1)
    @admin = Admin.create(name: 'Bob', kind: 2)
    @deleted_post = Post.create(title: 'Deleted', user: @user, deleted_at: Time.now)
    @active_post = Post.create(title: 'Active', user: @user, deleted_at: nil)
  end

  context 'calculation methods' do
    
    describe '.count' do
      it 'works with default frame' do
        count = User.count
        expect(count).to eq(2) # user + admin, both have kind set
      end

      it 'works with named frame' do
        count = Post::Deleted.count
        expect(count).to eq(1)
      end
    end

    describe '.sum' do
      it 'works with frames' do
        sum = User.sum(:kind)
        expect(sum).to eq(3) # 1 + 2
      end
    end

    describe '.average' do
      it 'works with frames' do
        avg = User.average(:kind)
        expect(avg).to eq(1.5)
      end
    end

    describe '.minimum and .maximum' do
      it 'works with frames' do
        expect(User.minimum(:kind)).to eq(1)
        expect(User.maximum(:kind)).to eq(2)
      end
    end

  end

  context 'pluck and pick' do
    
    describe '.pluck' do
      it 'works with single column' do
        names = User.pluck(:name)
        expect(names).to contain_exactly('Alice', 'Bob')
      end

      it 'works with multiple columns' do
        data = User.pluck(:name, :kind)
        expect(data).to contain_exactly(['Alice', 1], ['Bob', 2])
      end

      it 'works with named frame' do
        titles = Post::Deleted.pluck(:title)
        expect(titles).to eq(['Deleted'])
      end
    end

    describe '.pick' do
      it 'works with frames' do
        skip "pick method added in Rails 6.0" if ActiveRecord::VERSION::MAJOR < 6
        name = User.order(:kind).pick(:name)
        expect(name).to eq('Alice')
      end
    end

  end

  context 'find methods' do
    
    describe '.find' do
      it 'respects frames when finding by id' do
        expect(User.find(@user.id)).to eq(@user)
      end

      it 'raises if record filtered by frame' do
        user_without_kind = User.unframed.create(name: 'NoKind', kind: nil)
        
        expect {
          User.find(user_without_kind.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe '.find_by' do
      it 'respects frames' do
        user = User.find_by(name: 'Alice')
        expect(user).to eq(@user)
      end
    end

    describe '.first, .last' do
      it 'respects frames' do
        expect(User.first).to be_a(User)
        expect(Post::Deleted.first).to eq(@deleted_post)
      end
    end

  end

  context 'update and delete methods' do
    
    describe '.update_all' do
      it 'respects frames' do
        User.update_all(name: 'Updated')
        expect(@user.reload.name).to eq('Updated')
      end

      it 'only updates records in frame' do
        Post::Deleted.update_all(title: 'Changed')
        expect(@deleted_post.reload.title).to eq('Changed')
        expect(@active_post.reload.title).to eq('Active')
      end
    end

    describe '.delete_all' do
      it 'respects frames' do
        Post::Deleted.delete_all
        expect(Post.unframed.count).to eq(1) # Only active_post remains
      end
    end

    describe '.destroy_all' do
      it 'respects frames and runs callbacks' do
        count_before = Post.unframed.count
        Post::Deleted.destroy_all
        expect(Post.unframed.count).to eq(count_before - 1)
      end
    end

  end

  context 'batching methods' do
    
    describe '.find_each' do
      it 'works with frames' do
        names = []
        User.find_each do |user|
          names << user.name
        end
        expect(names).to contain_exactly('Alice', 'Bob')
      end
    end

    describe '.find_in_batches' do
      it 'works with frames' do
        batches = []
        User.find_in_batches(batch_size: 1) do |batch|
          batches << batch
        end
        expect(batches.size).to eq(2)
      end
    end

    describe '.in_batches' do
      it 'works with frames' do
        count = 0
        User.in_batches do |relation|
          count += relation.count
        end
        expect(count).to eq(2)
      end
    end

  end

  context 'query modifiers' do
    
    describe '.select' do
      it 'works with custom select' do
        users = User.select(:id, :name)
        expect(users.first.name).to eq('Alice')
      end

      it 'works with select and frames' do
        sql = User.select(:name).to_sql
        expect(sql).to include('WITH')
        expect(sql).to include('SELECT "users"."name"')
      end
    end

    describe '.distinct' do
      it 'works with frames' do
        users = User.distinct
        expect(users.count).to eq(2)
      end
    end

    describe '.group and .having' do
      it 'works with frames' do
        groups = User.group(:kind).count
        expect(groups).to eq({1 => 1, 2 => 1})
      end

      it 'works with having' do
        groups = User.group(:kind).having('COUNT(*) > 0').count
        expect(groups.size).to be > 0
      end
    end

    describe '.lock' do
      it 'works with frames' do
        user = User.lock.first
        expect(user).to be_a(User)
      end
    end

    describe '.readonly' do
      it 'works with frames' do
        user = User.readonly.first
        expect(user).to be_readonly
      end
    end

  end

  context 'scopes and where chains' do
    
    it 'chains where conditions with frames' do
      user = User.where(name: 'Alice').first
      expect(user).to eq(@user)
    end

    it 'chains multiple where conditions' do
      user = User.where(name: 'Alice').where(kind: 1).first
      expect(user).to eq(@user)
    end

    it 'works with not' do
      users = User.where.not(name: 'Alice')
      expect(users).to contain_exactly(@admin)
    end

    it 'works with or' do
      users = User.where(name: 'Alice').or(User.where(name: 'Bob'))
      expect(users.count).to eq(2)
    end

  end

  context 'exists? and any?' do
    
    describe '.exists?' do
      it 'works with frames' do
        expect(User.exists?(@user.id)).to be true
      end

      it 'respects frame filtering' do
        user_without_kind = User.unframed.create(name: 'NoKind', kind: nil)
        expect(User.exists?(user_without_kind.id)).to be false
      end
    end

    describe '.any?' do
      it 'works with frames' do
        expect(User.any?).to be true
        expect(Post::Deleted.any?).to be true
      end
    end

    describe '.none?' do
      it 'works with frames' do
        expect(User.none?).to be false
      end
    end

  end

  context 'subqueries' do
    
    it 'works with WHERE ... IN (SELECT ...)' do
      user_ids = User.where(kind: 1).select(:id)
      posts = Post.where(user_id: user_ids)
      
      expect(posts.to_sql).to include('WITH')
      expect(posts).to include(@active_post, @deleted_post)
    end

    it 'works with EXISTS subqueries' do
      # This is tricky - frames in subqueries
      users_with_posts = User.where('EXISTS (SELECT 1 FROM documents WHERE documents.user_id = users.id)')
      expect(users_with_posts).to include(@user)
    end

  end

  context 'raw SQL fragments' do
    
    it 'works with raw where conditions' do
      users = User.where('name = ?', 'Alice')
      expect(users.first).to eq(@user)
    end

    it 'works with from clause' do
      users = User.from('users AS u')
      expect(users).not_to be_empty
    end

  end

end
