class CreatePrimaryReplies < ActiveRecord::Migration
  def change
    create_table :primary_replies do |t|
      t.integer :topic_id, null: false
      t.integer :user_id, null: false
      t.text :content, null: false
      t.text :program
      t.string :language, limit: 10
      t.boolean :enable_markdown, null: false, default: false
      t.boolean :hidden, null: false, default: false

      t.timestamps
    end
    add_index :primary_replies, :topic_id
    add_index :primary_replies, :created_at
  end
end
