class Tag < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  default_scope order('name ASC')
  has_and_belongs_to_many :problems

  attr_accessible :name
  attr_accessible :problems

  validates :name, uniqueness: true
  validates :name, presence: true
  validates :name, length: { maximum: 20 }
end
