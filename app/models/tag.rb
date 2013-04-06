class Tag < ActiveRecord::Base
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
      Tag.find_by_sql ['SELECT * FROM tags WHERE id IN (:ids) ORDER BY name', ids: Tag.valid_ids]
    end
  end

  def self.clear_cache
    Rails.cache.delete 'model/tag/valid_ids'
    Rails.cache.delete 'model/tag/valid_entry'
  end
end
