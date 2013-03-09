class CreateProblemContents < ActiveRecord::Migration
  def change
    create_table :problem_contents do |t|
      t.integer :problem_id, null: false
      t.string :time_limit, null: false, limit: 20
      t.string :memory_limit, null: false, limit: 20
      t.text :background, null: false, default: ''
      t.text :description, null: false, default: ''
      t.text :input, null: false, default: ''
      t.text :output, null: false, default: ''
      t.text :sample_illustration, null: false, default: ''
      t.text :additional_information, null: false, default: ''
      t.boolean :enable_markdown, null: false, default: true
      t.boolean :enable_latex, null: false, default: false
      t.text :program, null: false, default: ''
      t.string :language, limit: 10
      t.text :solution, null: false, default: ''

      t.timestamps
    end
    add_index :problem_contents, :problem_id
  end
end
