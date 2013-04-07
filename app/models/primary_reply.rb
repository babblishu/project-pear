class PrimaryReply < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  belongs_to :topic
  belongs_to :user
  has_many :secondary_replies, order: 'created_at ASC, id ASC'

  attr_accessible :topic
  attr_accessible :user
  attr_accessible :content
  attr_accessible :program
  attr_accessible :language
  attr_accessible :enable_markdown
  attr_protected :hidden
  attr_protected :secondary_replies

  validates :content, presence: true
  validates :content, length: { maximum: APP_CONFIG.primary_reply_length_limit }
  validates :language, inclusion: { in: APP_CONFIG.program_languages.keys.map(&:to_s) << nil }

  def page_no
    page_size = APP_CONFIG.page_size[:topic_replies_list]
    count = PrimaryReply.where('topic_id = :topic_id AND (created_at < :time OR created_at = :time AND id <= :id)',
                               topic_id: topic_id, time: created_at, id: id).count
    count < page_size ? 1 : count / page_size + 1
  end
end
