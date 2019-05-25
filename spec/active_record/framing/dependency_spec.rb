require "spec_helper"

describe ActiveRecord::Framing::Dependency do

  context '#walk_tree' do
    it 'should handle a hash' do
      tree = [{:posts=>{:comments=>{:votes=>:foo}}}]
      expect(ActiveRecord::Framing::Dependency.walk_tree(tree, Hash.new).to_h).to eq({
        posts: {
          associations: {
            comments: {
              associations: {
                votes: {
                  relation: :foo
                }
              }
            }
          }
        }
      })
    end
  end
end
