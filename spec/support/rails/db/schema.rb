ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, schema: :public, force: true do |t|
    t.string :type
    t.string :name
    t.string :email, index: :btree
    t.integer :kind, default: 0
    t.timestamps null: false
  end

  create_table :documents, force: true do |t|
    t.integer :user_id
    t.string :title
    t.integer :version,    default: [1, 0], null: false, array: true
    t.integer :scope
    t.timestamps null: false
    t.timestamp :deleted_at
  end

  create_table :comments, force: true do |t|
    t.string :title
    t.integer :user_id
    t.integer :post_id
    t.timestamps null: false
  end

end
