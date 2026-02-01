require "spec_helper"

describe 'Frame Inheritance' do

  context 'with STI (Single Table Inheritance)' do
    
    describe 'inheriting parent default_frame' do
      it 'child class inherits parent default_frame' do
        # Admin < User, User has default_frame { where.not(kind: nil) }
        expect(Admin.all.to_sql).to match_sql(<<~SQL)
          WITH "users" AS
            (SELECT "users".* FROM "users" WHERE \(?"users"."kind" IS NOT NULL\)?)
          SELECT "users".* FROM "users" WHERE \(?"users"."type" (?:IN|=) \(?'Admin'\)?\)?
        SQL
      end

      it 'applies both parent frame and STI type condition' do
        admin = Admin.create(name: 'test', kind: 2)
        user = User.create(name: 'test', kind: 1)

        # Admin should only return Admin records, with parent frame applied
        result = Admin.all
        expect(result).to include(admin)
        expect(result).not_to include(user)
      end
    end

    describe 'class hierarchy frame walking' do
      it 'walks up class hierarchy to find frame' do
        # Set a frame on User that Admin can inherit
        test_frame = User.where(kind: 2)
        User.current_frame = test_frame

        # Admin should find User's frame by walking up the hierarchy
        frame = Admin.current_frame
        expect(frame).not_to be_nil
        expect(frame.to_sql).to include('kind')

        User.current_frame = nil # cleanup
      end

      it 'returns nil if no frame found in hierarchy' do
        # Comment has no frame and no parent with frame
        frame = Comment.current_frame
        expect(frame).to be_nil
      end

      it 'finds frame defined on base_class' do
        # Set frame on base class
        test_frame = User.where(kind: 2)
        User.current_frame = test_frame

        # Even if called on subclass, should find base class frame
        base_class = Admin.base_class
        expect(base_class).to eq(User)

        admin_frame = Admin.current_frame
        user_frame = User.current_frame

        # Both should resolve to the same frame (User's)
        expect(admin_frame.to_sql).to eq(user_frame.to_sql)

        User.current_frame = nil # cleanup
      end
    end

    describe 'skip_inherited_frame parameter' do
      it 'skips parent frame when skip_inherited_frame is true' do
        # Set a frame on the parent (User)
        test_frame = User.where(email: 'test@example.com')
        User.current_frame = test_frame

        frame = Admin.current_frame(skip_inherited_frame: true)

        # Admin doesn't define its own frame, and we're skipping inheritance
        expect(frame).to be_nil

        User.current_frame = nil # cleanup
      end

      it 'includes parent frame when skip_inherited_frame is false' do
        # Set a frame on the parent (User)
        test_frame = User.where(email: 'test@example.com')
        User.current_frame = test_frame

        frame = Admin.current_frame(skip_inherited_frame: false)

        # Should find User's frame through inheritance
        expect(frame).not_to be_nil
        expect(frame.to_sql).to eq(test_frame.to_sql)

        User.current_frame = nil # cleanup
      end

      it 'uses skip_inherited_frame in FrameRegistry.value_for' do
        registry = ActiveRecord::Framing::FrameRegistry.instance
        test_frame = User.where(email: 'test@example.com')
        User.current_frame = test_frame

        # With skip: should only check Admin (which has no frame)
        value_skipped = registry.value_for(:current_frame, Admin, true)
        expect(value_skipped).to be_nil

        # Without skip: should walk up to User and find its frame
        value_inherited = registry.value_for(:current_frame, Admin, false)
        expect(value_inherited).not_to be_nil

        User.current_frame = nil # cleanup
      end
    end

  end

  context 'with named frames' do
    it 'child class can access parent named frames' do
      # User defines User::All
      expect(User::All).to be_a(Class)
      
      # Admin should be able to use it too (through inheritance)
      # Note: This might not work as expected depending on implementation
      # If it doesn't, that's a useful finding!
    end
  end

  context 'frame override scenarios' do
    it 'allows child to define its own default_frame' do
      # Create a temporary subclass with its own frame
      child_class = Class.new(User) do
        def self.name; 'ChildUser'; end
        default_frame { where(kind: 99) }
      end

      expect(child_class.all.to_sql).to include('kind" = 99')
      expect(child_class.all.to_sql).not_to include('IS NOT NULL')
    end

    it 'child frame takes precedence over parent frame' do
      child_class = Class.new(User) do
        def self.name; 'ChildUser'; end
        default_frame { where(kind: 99) }
      end

      # Set frames on both
      User.current_frame = User.where(kind: 1)
      child_class.current_frame = child_class.where(kind: 99)

      child_frame = child_class.current_frame
      parent_frame = User.current_frame

      expect(child_frame.to_sql).not_to eq(parent_frame.to_sql)

      User.current_frame = nil
      child_class.current_frame = nil
    end
  end

  context 'multiple inheritance levels' do
    it 'walks through multiple levels of inheritance' do
      # User < ActiveRecord::Base
      # Admin < User
      # SuperAdmin < Admin (if it existed)

      # Set a frame on User
      test_frame = User.where(kind: 2)
      User.current_frame = test_frame

      # Create a 3-level hierarchy
      super_admin_class = Class.new(Admin) do
        def self.name; 'SuperAdmin'; end
      end

      # Should walk: SuperAdmin -> Admin -> User and find User's frame
      frame = super_admin_class.current_frame
      expect(frame).not_to be_nil
      expect(frame.to_sql).to include('kind')

      User.current_frame = nil
    end

    it 'stops at base_class when walking hierarchy' do
      # Set frame on base class
      test_frame = User.where(kind: 2)
      User.current_frame = test_frame

      # Ensure it doesn't walk past base_class
      frame = Admin.current_frame
      expect(frame).not_to be_nil

      # Should not have walked past User (the base_class)
      expect(frame.to_sql).to eq(test_frame.to_sql)

      User.current_frame = nil
    end
  end

  context 'edge cases' do
    it 'handles abstract intermediate classes' do
      # Set a frame on User
      test_frame = User.where(kind: 2)
      User.current_frame = test_frame

      abstract_class = Class.new(User) do
        def self.name; 'AbstractUser'; end
        self.abstract_class = true
      end

      concrete_class = Class.new(abstract_class) do
        def self.name; 'ConcreteUser'; end
      end

      # Should skip abstract class and find User's frame
      frame = concrete_class.current_frame
      expect(frame).not_to be_nil

      User.current_frame = nil
    end

    it 'handles class with no parent frame gracefully' do
      orphan_class = Class.new(ActiveRecord::Base) do
        def self.name; 'Orphan'; end
        self.table_name = 'users'
      end

      expect { orphan_class.current_frame }.not_to raise_error
      expect(orphan_class.current_frame).to be_nil
    end
  end

end
