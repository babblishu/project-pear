class CreateTopics < ActiveRecord::Migration
  def change
    create_table :topics do |t|
      t.string :status, null: false, limit: 20, default: 'normal'
      t.integer :user_id, null: false
      t.integer :problem_id
      t.string :title, null: false, limit: 20
      t.text :content, null: false
      t.text :program
      t.string :language, limit: 10
      t.boolean :enable_markdown, null: false, default: false
      t.boolean :top, null: false, default: false
      t.boolean :no_reply, null: false, default: false

      t.timestamps
    end
    add_index :topics, :status
    add_index :topics, :user_id
    add_index :topics, :problem_id
    add_index :topics, :created_at
  end
end
