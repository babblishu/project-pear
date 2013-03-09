class Tag < ActiveRecord::Base
  default_scope order('name ASC')
  has_and_belongs_to_many :problems

  attr_accessible :name
  attr_accessible :problems

  validates :name, uniqueness: true
  validates :name, presence: true
  validates :name, length: { maximum: 20 }

  def self.clear_empty
    Tag.all.each do |tag|
      tag.delete if tag.problems.size == 0
    end
  end
end
