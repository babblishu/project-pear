class Notification < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  belongs_to :user

  attr_accessible :user
  attr_accessible :content
  attr_accessible :read

  def self.list(user_id, excepted_ids, page_size)
    if excepted_ids.empty?
      Notification.where('user_id = :user_id', user_id: user_id).
          order('read ASC, created_at DESC').limit(page_size + 1).to_a
    else
      Notification.where('user_id = :user_id AND NOT (id IN (:set))', user_id: user_id, set: excepted_ids).
          order('read ASC, created_at DESC').limit(page_size + 1).to_a
    end
  end
end
