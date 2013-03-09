class CreateSampleTestData < ActiveRecord::Migration
  def change
    create_table :sample_test_data do |t|
      t.text :input, null: false
      t.text :output, null: false
      t.integer :problem_id, null: false
      t.integer :case_no, null: false

      t.timestamps
    end
    add_index :sample_test_data, :problem_id
  end
end
