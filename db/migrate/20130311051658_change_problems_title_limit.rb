class ChangeProblemsTitleLimit < ActiveRecord::Migration
  def up
    change_column :problems, :title, :string, limit: 100
  end

  def down
    change_column :problems, :title, :string, limit: 20
  end
end
