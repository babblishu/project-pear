class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.integer :user_from, null: false
      t.integer :user_to, null: false
      t.boolean :read, null: false, default: false
      t.string :content, null: false, limit: 250

      t.timestamps
    end
    add_index :messages, :user_from
    add_index :messages, :user_to
    add_index :messages, [:user_to, :read]
  end
end
