class SecondaryReply < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  belongs_to :topic
  belongs_to :primary_reply
  belongs_to :user

  attr_accessible :topic
  attr_accessible :primary_reply
  attr_accessible :user
  attr_accessible :content
  attr_protected :hidden

  validates :content, presence: true
  validates :content, length: { maximum: APP_CONFIG.secondary_reply_length_limit }
end
