class Notification < ActiveRecord::Base
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

  def self.unread_notifications(user_id)
    key = APP_CONFIG.redis_namespace[:user_unread_notifications] + user_id.to_s
    ($redis.get(key) || rebuild_unread_notifications(user_id)).to_i
  end

  def self.rebuild_unread_notifications(user_id)
    key = APP_CONFIG.redis_namespace[:user_unread_notifications] + user_id.to_s
    loop do
      $redis.watch(key)
      value = Notification.where('user_id = :user_id AND NOT read', user_id: user_id).count
      return value if $redis.multi { |multi| $redis.set(key, value) }
    end
  end
end
