require 'ostruct'

class Message < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  belongs_to :from, foreign_key: 'user_from', class_name: 'User'
  belongs_to :to, foreign_key: 'user_to', class_name: 'User'

  attr_accessible :from
  attr_accessible :to
  attr_accessible :content
  attr_accessible :read

  validates :content, presence: true
  validates :content, length: { maximum: APP_CONFIG.message_length_limit }

  def self.list_count(user_id)
    connection.execute(sanitize_sql_array([
        %q{
           SELECT COUNT(DISTINCT x.user_id)
           FROM (
               SELECT user_to AS user_id
               FROM messages
               WHERE user_from = :user_id
               UNION ALL (
                   SELECT user_from AS user_id
                   FROM messages
                   WHERE user_to = :user_id
               )
           ) AS x
        },
        user_id: user_id,
    ])).first['count'].to_i
  end

  def self.list(user_id, page, page_size)
    messages = connection.execute(sanitize_sql_array([
        %q{
           SELECT y.user_id, y.content, y.read, y.created_at
           FROM (
               SELECT x.user_id, x.content, x.read, x.created_at,
                      RANK() OVER (PARTITION BY x.user_id ORDER BY x.read ASC, x.created_at DESC) AS pos
               FROM (
                   SELECT user_to AS user_id, content, TRUE AS read, created_at
                   FROM messages
                   WHERE user_from = :user_id
                   UNION ALL (
                       SELECT user_from AS user_id, content, read, created_at
                       FROM messages
                       WHERE user_to = :user_id
                   )
               ) AS x
           ) AS y
           WHERE y.pos = 1
           ORDER BY y.read ASC, y.created_at DESC
           OFFSET :offset LIMIT :limit
        },
        user_id: user_id,
        offset: (page - 1) * page_size, limit: page_size
    ])).map do |row|
      OpenStruct.new(
          user_id: row['user_id'].to_i,
          content: row['content'],
          read: row['read'] == 't',
          created_at: Time.parse(row['created_at'] + ' UTC')
      )
    end
    users = Hash[User.find(messages.map(&:user_id)).map { |user| [user.id, user] }]
    messages.each { |message| message.user = users[message.user_id] }
    messages
  end

  def self.detail_list(user_id_1, user_id_2, excepted_ids, page_size)
    if excepted_ids.empty?
      @messages = Message.where('user_from = :user_id_1 AND user_to = :user_id_2 OR user_from = :user_id_2 AND user_to = :user_id_1',
                                user_id_1: user_id_1, user_id_2: user_id_2).
          order('created_at DESC').limit(page_size + 1).to_a
    else
      @messages = Message.where('(user_from = :user_id_1 AND user_to = :user_id_2 OR user_from = :user_id_2 AND user_to = :user_id_1) AND NOT id IN (:excepted_ids)',
                                user_id_1: user_id_1, user_id_2: user_id_2, excepted_ids: excepted_ids).
          order('created_at DESC').limit(page_size + 1).to_a
    end
  end
end
