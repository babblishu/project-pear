class UserInformation < ActiveRecord::Base
  attr_accessible :real_name
  attr_accessible :school
  attr_accessible :email
  attr_accessible :signature
  attr_accessible :show_real_name
  attr_accessible :show_school
  attr_accessible :show_email

  validates :real_name, presence: true
  validates :real_name, length: { maximum: 20 }
  validates :school, presence: true
  validates :school, length: { maximum: 50 }
  validates :email, presence: true
  validates :email, length: { maximum: 50 }
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  validates :signature, presence: true
  validates :signature, length: { maximum: 100 }
end
