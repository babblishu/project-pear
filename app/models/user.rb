require 'ostruct'

class User < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  has_secure_password
  has_attached_file :avatar, {
      styles: { large: '200x200', medium: '100x100', thumb: '75x75' },
      default_url: '/img/default_avatar_:style.png',
  }

  has_one :information, class_name: 'UserInformation', autosave: true

  attr_protected :remote_ip
  attr_protected :role
  attr_accessible :handle
  attr_accessible :password
  attr_accessible :password_confirmation
  attr_accessible :avatar
  attr_accessible :information
  attr_protected :blocked
  attr_protected :last_submit
  attr_protected :submit_times
  attr_protected :need_captcha

  validates :handle, uniqueness: { case_sensitive: false }
  validates :handle, format: { with: /\A[a-z0-9\._]*\Z/i }
  validates :handle, length: { minimum: 3, maximum: 15 }
  validates_attachment_content_type :avatar, {
      content_type: ['image/png', 'image/jpeg', 'image/jpg'],
      message: I18n.t('activerecord.errors.models.user.attributes.avatar.invalid_type')
  }
  validates_attachment_size :avatar, {
      in: 0..100.kilobytes,
      message: I18n.t('activerecord.errors.models.user.attributes.avatar.too_large')
  }
  validate :file_dimensions

  def file_dimensions
    file = avatar.queued_for_write[:original]
    return unless file
    dimensions = Paperclip::Geometry.from_file(file.path)
    unless dimensions.width == dimensions.height
      errors.add(:avatar, I18n.t('activerecord.errors.models.user.attributes.avatar.not_square'))
    end
    unless dimensions.width >= 200
      errors.add(:avatar, I18n.t('activerecord.errors.models.user.attributes.avatar.too_small'))
    end
  end

  def rank
    User.get_user_rank accepted_problems, id
  end

  def accepted_problems(time = nil)
    if time
      Submission.where("user_id = :user_id AND score = 100 AND status = 'judged' AND NOT hidden AND created_at >= :time",
                       user_id: id, time: time).
          count(:problem_id, distinct: true)
    else
      Submission.where("user_id = :user_id AND score = 100 AND status = 'judged' AND NOT hidden", user_id: id).
          count(:problem_id, distinct: true)
    end

  end

  def attempted_problems(time = nil)
    if time
      Submission.where("user_id = :user_id AND status = 'judged' AND NOT hidden AND NOT hidden AND created_at >= :time",
                       user_id: id, time: time).
          count(:problem_id, distinct: true)
    else
      Submission.where("user_id = :user_id AND status = 'judged' AND NOT hidden", user_id: id).
          count(:problem_id, distinct: true)
    end
  end

  def accepted_submissions(time = nil)
    if time
      Submission.where("user_id = :user_id AND score = 100 AND status = 'judged' AND NOT hidden AND created_at >= :time",
                       user_id: id, time: time).count
    else
      Submission.where("user_id = :user_id AND score = 100 AND status = 'judged' AND NOT hidden", user_id: id).count
    end
  end

  def attempted_submissions(time = nil)
    if time
      Submission.where("user_id = :user_id AND status = 'judged' AND NOT hidden AND created_at >= :time",
                       user_id: id, time: time).count
    else
      Submission.where("user_id = :user_id AND status = 'judged' AND NOT hidden", user_id: id).count
    end

  end

  def accepted_problem_ids
    Submission.select('DISTINCT(problem_id)').
        where("user_id = :user_id AND score = 100 AND status = 'judged' AND NOT hidden", user_id: id).
        order('problem_id ASC').map(&:problem_id)
  end

  def attempted_problem_ids
    Submission.select('DISTINCT(problem_id)').
        where("user_id = :user_id AND status = 'judged' AND NOT hidden", user_id: id).
        order('problem_id ASC').map(&:problem_id)
  end

  def self.get_user_rank(accepted_problems, user_id)
    return nil if accepted_problems == 0
    connection.execute(sanitize_sql_array([
        %q{
           SELECT COUNT(*)
           FROM (
               SELECT user_id, COUNT(DISTINCT problem_id) AS accepted_problems
               FROM submissions
               WHERE score = 100 AND status = 'judged' AND NOT hidden
               GROUP BY user_id
           ) AS x
           WHERE x.accepted_problems > :cnt OR (x.accepted_problems = :cnt AND x.user_id <= :id)
        },
        cnt: accepted_problems, id: user_id
    ])).first['count'].to_i
  end

  def self.rank_list(time, page, page_size)
    list = connection.execute(sanitize_sql_array([
        %q{
           SELECT user_id AS id, COUNT(DISTINCT problem_id) AS accepted_problems,
                  COUNT(problem_id) AS accepted_submissions
           FROM submissions
           WHERE created_at >= :time AND score = 100 AND status = 'judged' AND NOT hidden
           GROUP BY user_id
           ORDER BY accepted_problems DESC, user_id ASC
           OFFSET :offset LIMIT :limit
        },
        time: time, offset: (page - 1) * page_size, limit: page_size + 1
    ])).map do |row|
      OpenStruct.new(
        id: row['id'].to_i,
        accepted_problems: row['accepted_problems'].to_i,
        accepted_submissions: row['accepted_submissions'].to_i
      )
    end
    ids = list.map { |user| user.id }
    tmp_hash = Hash[connection.execute(sanitize_sql_array([
        %q{
           SELECT users.id, users.handle, t.attempted_problems, t.attempted_submissions
           FROM users
           INNER JOIN (
               SELECT user_id,
                      COUNT(DISTINCT problem_id) AS attempted_problems,
                      COUNT(*) AS attempted_submissions
               FROM submissions
               WHERE created_at >= :time AND user_id IN (:ids) AND status = 'judged' AND NOT hidden
               GROUP BY user_id
           ) AS t ON users.id = t.user_id
        },
        time: time, ids: ids
    ])).map { |row| [ row['id'].to_i, [row['handle'], row['attempted_problems'].to_i, row['attempted_submissions'].to_i] ] }]
    list.each do |user|
      user.handle = tmp_hash[user.id][0]
      user.attempted_problems = tmp_hash[user.id][1]
      user.attempted_submissions = tmp_hash[user.id][2]
    end
    list
  end

  def self.top_users(time, limit)
    list = connection.execute(sanitize_sql_array([
        %q{
           SELECT user_id AS id, COUNT(DISTINCT problem_id) AS accepted_problems
           FROM submissions
           WHERE created_at >= :time AND score = 100 AND status = 'judged' AND NOT hidden
           GROUP BY user_id
           ORDER BY accepted_problems DESC, user_id ASC
           LIMIT :limit
        },
        time: time, limit: limit
    ])).map do |row|
      OpenStruct.new(
          id: row['id'].to_i,
          accepted_problems: row['accepted_problems'].to_i,
      )
    end
    ids = list.map { |user| user.id }
    tmp_hash = Hash[connection.execute(sanitize_sql_array([
        %q{
           SELECT users.id, users.handle
           FROM users
           WHERE id IN (:ids)
        },
        ids: ids
    ])).map { |row| [ row['id'].to_i, row['handle'] ] }]
    list.each { |user| user.handle = tmp_hash[user.id] }
    list
  end
end
