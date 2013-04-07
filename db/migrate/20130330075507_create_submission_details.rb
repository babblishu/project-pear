class CreateSubmissionDetails < ActiveRecord::Migration
  def change
    create_table :submission_details do |t|
      t.integer :submission_id, null: false
      t.text :program, null: false
      t.text :result

      t.timestamps
    end
    add_index :submission_details, :submission_id
  end
end
