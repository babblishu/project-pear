class Tag < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  has_and_belongs_to_many :problems

  attr_accessible :name
  attr_accessible :problems

  validates :name, uniqueness: true
  validates :name, presence: true
  validates :name, length: { maximum: 20 }

  def self.valid_ids
    Rails.cache.fetch('model/tag/valid_ids') do
      connection.execute('SELECT DISTINCT tag_id FROM problems_tags').map { |row| row['tag_id'].to_i }
    end
  end

  def self.valid_entry
    Rails.cache.fetch('model/tag/valid_entry') do
      Tag.valid_ids.map { |id| Tag.find_by_id id }.sort! { |x, y| x.name <=> y.name }
    end
  end
end
