class CreateFaqs < ActiveRecord::Migration
  def change
    create_table :faqs do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :rank, null: false

      t.timestamps
    end
  end
end
