class CreateSecondaryReplies < ActiveRecord::Migration
  def change
    create_table :secondary_replies do |t|
      t.integer :primary_reply_id, null: false
      t.integer :user_id, null: false
      t.string :content, null: false, limit: 250
      t.boolean :hidden, null: false, default: false

      t.timestamps
    end
    add_index :secondary_replies, :primary_reply_id
    add_index :secondary_replies, :created_at
  end
end
