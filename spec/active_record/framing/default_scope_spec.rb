require 'spec_helper'

# A default-framed relation must honor the model's default_scope exactly as
# stock ActiveRecord does: the frame (CTE) narrows the source table, and the
# default_scope still filters the outer query.
#
#   User: default_scope { where(kind: 1) }, default_frame { where.not(kind: nil) }
#   Post: default_scope { where(scope: 1) }, default_frame { deleted_at IS NULL }
RSpec.describe 'default_scope on default-framed relations' do
  let!(:member)   { User.unscoped.create!(name: 'member', kind: 1) }
  let!(:outsider) { User.unscoped.create!(name: 'outsider', kind: 3) }

  describe '.all' do
    it 'excludes rows the default_scope filters out' do
      expect(User.all.to_a.map(&:id)).to eq([member.id])
    end

    it 'keeps the frame and applies the default_scope in the outer query' do
      sql = User.all.to_sql
      expect(sql).to start_with('WITH "users" AS (')
      expect(sql).to match(/\) SELECT "users"\.\* FROM "users" WHERE "users"\."kind" = 1\z/)
    end
  end

  describe '.count' do
    it 'counts only rows inside the default_scope' do
      expect(User.count).to eq(1)
    end

    it 'matches unframed when the frame filters nothing extra' do
      expect(User.count).to eq(User.unframed.count)
    end
  end

  describe 'where-chaining' do
    it 'combines chained conditions with the default_scope' do
      User.unscoped.create!(name: 'member', kind: 3)

      expect(User.where(name: 'member').count).to eq(1)
      expect(User.where(name: 'outsider').to_a).to be_empty
      expect(User.where(name: 'member').to_sql).to include('"users"."kind" = 1')
    end

    it 'ANDs a where on the same column with the default_scope, as in stock Rails' do
      expect(User.where(kind: 3).to_a).to be_empty
      expect(User.rewhere(kind: 3).to_a.map(&:id)).to eq([outsider.id])
    end
  end

  describe 'unscoped' do
    it 'drops the default_scope but keeps the frame' do
      expect(User.unscoped.count).to eq(2)
      expect(User.unscoped { User.all.count }).to eq(2)
      expect(User.unscoped { User.all.to_sql }).to start_with('WITH "users" AS (')
    end
  end

  describe 'associations' do
    it "applies the target model's default_scope and default_frame" do
      in_scope     = Post.unscoped.create!(user: member, title: 'in', scope: 1)
      _out_scope   = Post.unscoped.create!(user: member, title: 'out', scope: 2)
      _out_frame   = Post.unscoped.create!(user: member, title: 'deleted', scope: 1, deleted_at: Time.now)

      expect(member.posts.to_a.map(&:id)).to eq([in_scope.id])
      expect(member.posts.count).to eq(1)
    end

    it 'applies the default_scope through belongs_to' do
      post = Post.unscoped.create!(user: outsider, title: 'orphan', scope: 1)
      expect(Post.find(post.id).user).to be_nil
    end
  end
end
