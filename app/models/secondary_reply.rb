class SecondaryReply < ActiveRecord::Base
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
