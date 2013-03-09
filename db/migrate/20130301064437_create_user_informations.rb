class CreateUserInformations < ActiveRecord::Migration
  def change
    create_table :user_informations do |t|
      t.integer :user_id, null: false
      t.string :real_name, null: false, limit: 20
      t.string :school, null: false, limit: 50
      t.string :email, null: false, limit: 50
      t.string :signature, null: false, limit: 100
      t.boolean :show_real_name, null: false, default: false
      t.boolean :show_school, null: false, default: true
      t.boolean :show_email, null: false, default: true

      t.timestamps
    end
    add_index :user_informations, :user_id
  end
end
