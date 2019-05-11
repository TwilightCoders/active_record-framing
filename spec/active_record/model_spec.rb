require "spec_helper"

describe ActiveRecord::Base do

  it 'allows for default values in create' do
    post = Post.create()
    expect(post.version).to eq([1,0])
  end

end
