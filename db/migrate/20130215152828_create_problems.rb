class CreateProblems < ActiveRecord::Migration
  def change
    create_table :problems do |t|
      t.string :status, null: false, limit: 20, default: 'hidden'
      t.string :title, null: false, limit: 20
      t.string :source, null: false, default: '', limit: 100
      t.datetime :test_data_timestamp

      t.timestamps
    end
    execute('ALTER SEQUENCE problems_id_seq RESTART WITH 1000')
    add_index :problems, :status
  end
end
