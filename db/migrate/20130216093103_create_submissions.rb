class CreateSubmissions < ActiveRecord::Migration
  def change
    create_table :submissions do |t|
      t.string :remote_ip, limit: 30
      t.text :program, null: false
      t.string :language, null: false, limit: 10
      t.string :platform, null: false, limit: 20
      t.integer :user_id, null: false
      t.integer :problem_id, null: false
      t.integer :score
      t.string :status, null: false, default: 'waiting', limit: 20
      t.text :result
      t.integer :time_used
      t.integer :memory_used
      t.integer :code_size, null: false
      t.integer :code_length, null: false
      t.boolean :share, null: false, default: false
      t.boolean :hidden, null: false, default: false

      t.timestamps
    end
    add_index :submissions, :user_id
    add_index :submissions, :problem_id
    add_index :submissions, :language
    add_index :submissions, :platform
    add_index :submissions, :score
    add_index :submissions, :created_at
    add_index :submissions, [:platform, :status]
    add_index :submissions, [:language, :platform, :hidden]
    add_index :submissions, [:score, :status, :hidden]
    add_index :submissions, [:score, :status, :hidden, :user_id]
    add_index :submissions, [:status, :hidden, :user_id]
    add_index :submissions, [:score, :status, :hidden, :problem_id]
    add_index :submissions, [:status, :hidden, :problem_id]
  end
end
