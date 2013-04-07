require 'ostruct'

class Topic < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  belongs_to :user
  belongs_to :problem

  attr_accessible :problem
  attr_accessible :user
  attr_accessible :title
  attr_accessible :content
  attr_accessible :program
  attr_accessible :language
  attr_accessible :enable_markdown
  attr_protected :top
  attr_protected :no_reply
  attr_protected :status

  validates :title, presence: true
  validates :title, length: { maximum: 20 }
  validates :content, presence: true
  validates :content, length: { maximum: APP_CONFIG.topic_length_limit }
  validates :language, inclusion: { in: APP_CONFIG.program_languages.keys.map(&:to_s) << nil }

  def appear_users(page)
    key = APP_CONFIG.redis_namespace[:topic_appear_users] + "#{id}/#{page}"
    $redis.smembers(key)
  end

  def self.count_for_role(role)
    Rails.cache.fetch("model/topic/count_for_role/#{role}") do
      connection.execute(sanitize_sql_array([
          %q{
             SELECT COUNT(*)
             FROM topics AS x
             LEFT OUTER JOIN problems AS y ON x.problem_id = y.id
             WHERE x.status IN (:set) AND ((x.problem_id IS NULL) OR y.status IN (:set))
          },
          set: status_set_for_role(role)
      ])).first['count'].to_i
    end
  end

  def self.list_for_role(role, page, page_size)
    fetch_if(page_size == APP_CONFIG.page_size[:discuss_list], "model/topic/list/#{role}/#{page}") do
      connection.execute(sanitize_sql_array([
          %q{
             SELECT y.id AS id, y.problem_id AS problem_id, u.handle AS author,
                    y.title AS title, y.created_at AS created_at, x.last_reply AS last_reply,
                    x.replies_count AS replies_count, y.top AS top
             FROM (
                 SELECT id, COUNT(*) - 1 AS replies_count, MAX(created_at) AS last_reply
                 FROM (
                     SELECT id, created_at FROM topics
                     UNION ALL SELECT topic_id AS id, created_at FROM primary_replies
                     UNION ALL (
                         SELECT p.topic_id AS id, s.created_at
                         FROM secondary_replies AS s
                         INNER JOIN primary_replies AS p ON p.id = s.primary_reply_id
                     )
                 ) AS t
                 GROUP BY id
             ) AS x
             INNER JOIN topics AS y ON x.id = y.id AND y.status IN (:set)
             LEFT OUTER JOIN problems AS z ON y.problem_id = z.id
             INNER JOIN users AS u ON y.user_id = u.id
             WHERE (y.problem_id IS NULL) OR z.status IN (:set)
             ORDER BY
                 y.top DESC,
                 CASE WHEN y.top THEN y.created_at END,
                 CASE WHEN NOT y.top THEN x.last_reply END DESC
             OFFSET :offset LIMIT :limit
          },
          set: status_set_for_role(role),
          offset: (page - 1) * page_size, limit: page_size
      ])).map do |row|
        OpenStruct.new(
            id: row['id'].to_i,
            problem_id: row['problem_id'] ? row['problem_id'].to_i : nil,
            author: row['author'],
            title: row['title'],
            created_at: Time.parse(row['created_at'] + ' UTC'),
            last_reply: Time.parse(row['last_reply'] + ' UTC'),
            replies_count: row['replies_count'].to_i,
            top: row['top'] == 't'
        )
      end
    end
  end

  def self.count_with_problem_for_role(role, problem_id)
    Rails.cache.fetch("model/topic/count_with_problem_for_role/#{role}/#{problem_id}") do
      Topic.where('status IN (:set) AND problem_id = :problem_id',
                   set: status_set_for_role(role), problem_id: problem_id).count
    end
  end

  def self.list_with_problem_for_role(role, problem_id, page, page_size)
    Rails.cache.fetch("model/topic/list_with_problem/#{role}/#{problem_id}/#{page}") do
      connection.execute(sanitize_sql_array([
          %q{
             SELECT y.id AS id, u.handle AS author, y.title AS title, y.created_at AS created_at,
                    x.last_reply AS last_reply, x.replies_count AS replies_count, y.top AS top
             FROM (
                 SELECT id, COUNT(*) - 1 AS replies_count, MAX(created_at) AS last_reply
                 FROM (
                     SELECT id, created_at FROM topics
                     UNION ALL SELECT topic_id AS id, created_at FROM primary_replies
                     UNION ALL (
                         SELECT p.topic_id AS id, s.created_at
                         FROM secondary_replies AS s
                         INNER JOIN primary_replies AS p ON p.id = s.primary_reply_id
                     )
                 ) AS t
                 GROUP BY id
             ) AS x
             INNER JOIN topics AS y ON x.id = y.id AND y.problem_id = :problem_id AND y.status IN (:set)
             INNER JOIN users AS u ON y.user_id = u.id
             ORDER BY
                 y.top DESC,
                 CASE WHEN y.top THEN y.created_at END ASC,
                 CASE WHEN NOT y.top THEN x.last_reply END DESC
             OFFSET :offset LIMIT :limit
          },
          set: status_set_for_role(role), problem_id: problem_id,
          offset: (page - 1) * page_size, limit: page_size
      ])).map do |row|
        OpenStruct.new(
            id: row['id'].to_i,
            author: row['author'],
            title: row['title'],
            created_at: Time.parse(row['created_at'] + ' UTC'),
            last_reply: Time.parse(row['last_reply'] + ' UTC'),
            replies_count: row['replies_count'].to_i,
            top: row['top'] == 't'
        )
      end
    end
  end

  def self.clear_list_cache(problem_id = nil)
    page_size = APP_CONFIG.page_size[:discuss_list]
    %w{normal_user advanced_user admin}.each do |role|
      if problem_id
        Rails.cache.delete "model/topic/count_with_problem_for_role/#{role}/#{problem_id}"
        total_page = (count_with_problem_for_role(role, problem_id) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          Rails.cache.delete "model/topic/list_with_problem/#{role}/#{problem_id}/#{page}"
        end
      else
        Rails.cache.delete "model/topic/count_for_role/#{role}"
        total_page = (count_for_role(role) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          Rails.cache.delete "model/topic/list/#{role}/#{page}"
        end
      end
    end
  end

  def add_appear_users(page, handle)
    key = APP_CONFIG.redis_namespace[:topic_appear_users] + id.to_s + "/#{page}"
    $redis.sadd(key, handle)
  end

  def self.init_appear_users
    key = APP_CONFIG.redis_namespace[:topic_appear_users] + 'exists'
    return if $redis.exists(key)
    $redis.set(key, 1)
    Topic.all.each do |topic|
      key = APP_CONFIG.redis_namespace[:topic_appear_users] + topic.id.to_s + '/1'
      $redis.sadd(key, topic.user.handle)
    end
    PrimaryReply.all.each do |primary_reply|
      key = APP_CONFIG.redis_namespace[:topic_appear_users] + "#{primary_reply.topic_id}/#{primary_reply.page_no}"
      $redis.sadd(key, primary_reply.user.handle)
      primary_reply.secondary_replies.each do |secondary_reply|
        $redis.sadd(key, secondary_reply.user.handle)
      end
    end
  end

  private
  def self.status_set_for_role(role)
    set = ['normal']
    set << 'advanced' if role == 'advanced_user' || role == 'admin'
    set << 'hidden' if role == 'admin'
    set
  end

  def self.fetch_if(condition, name)
    if condition
      Rails.cache.fetch(name) { yield }
    else
      yield
    end
  end
end
