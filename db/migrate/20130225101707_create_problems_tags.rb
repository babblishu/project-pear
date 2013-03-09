class CreateProblemsTags < ActiveRecord::Migration
  def change
    create_table :problems_tags do |t|
      t.integer :problem_id, null: false
      t.integer :tag_id, null: false
    end
    add_index :problems_tags, :problem_id
    add_index :problems_tags, :tag_id
  end
end
