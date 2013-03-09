class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :remote_ip, limit: 30
      t.string :handle, null: false, unique: true, limit: 15
      t.string :password_digest, null: false
      t.string :role, null: false, limit: 20, default: 'normal_user'
      t.boolean :blocked, null: false, default: false

      t.datetime :last_submit, null: false
      t.integer :submit_times, null: false, default: 0
      t.boolean :need_captcha, null: false, default: false

      t.timestamps
    end
    add_index :users, :handle
  end
end
