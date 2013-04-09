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

  def self.valid_entry(role)
    Rails.cache.fetch("model/tag/valid_entry/#{role}") do
      Tag.find_by_sql [
          %q{
             SELECT * FROM tags
             WHERE id IN (
                 SELECT DISTINCT tag_id
                 FROM problems_tags AS x
                 INNER JOIN problems AS y ON x.problem_id = y.id AND y.status IN (:set)
             )
             ORDER BY name
          },
          set: status_set_for_role(role)
      ]
    end
  end

  def self.clear_cache
    Rails.cache.delete 'model/tag/valid_ids'
    %w{normal_user advanced_user admin}.each do |role|
      Rails.cache.delete "model/tag/valid_entry/#{role}"
    end
  end

  private
  def self.status_set_for_role(role)
    set = ['normal']
    set << 'advanced' if role == 'advanced_user' || role == 'admin'
    set << 'hidden' if role == 'admin'
    set
  end
end
