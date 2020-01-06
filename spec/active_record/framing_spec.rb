require "spec_helper"

describe ActiveRecord::Framing do

  context '#disable' do
    it 'allows for default values in create' do
      Post.create(deleted_at: Time.now, scope: 1)

      # post = ActiveRecord::Framing.disable do
      #   Post.all.first
      # end

      post = Post.unframed do
        Post.all.first
      end

      post2 = Post.all.first

      expect(post).to_not be_nil
      expect(post2).to be_nil
    end
  end

end
