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
    User.get_rank id
  end

  def accepted_problems(now = nil, span = 'all')
    User.accepted_problems([id], now, span).first
  end

  def attempted_problems(now = nil, span = 'all')
    User.attempted_problems([id], now, span).first
  end

  def accepted_submissions(now = nil, span = 'all')
    User.accepted_submissions([id], now, span).first
  end

  def attempted_submissions(now = nil, span = 'all')
    User.attempted_submissions([id], now, span).first
  end

  def accepted_problem_ids(now = nil, span = 'all')
    User.accepted_problem_ids(id, now, span)
  end

  def attempted_problem_ids(now = nil, span = 'all')
    User.attempted_problem_ids(id, now, span)
  end

  def refresh_avatar_url
    %w{thumb medium}.each do |style|
      key = APP_CONFIG.redis_namespace[:user_avatar_url] + style
      $redis.hset(key, handle, avatar.url(style.to_sym))
    end
  end

  def self.get_rank(id)
    key = APP_CONFIG.redis_namespace[:user_rank_list]
    rebuild_rank_list(nil, 'all') unless $redis.exists(key)
    res = $redis.zrevrank(key, id)
    res = res.to_i + 1 if res
    res
  end

  def self.accepted_submissions(ids, now, span)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:user_accepted_submissions]
    if span == 'all'
      res = $redis.mget(ids.map { |id| prefix + id.to_s })
    else
      time, dummy = get_time_and_expire now, span
      res = $redis.mget(ids.map { |id| prefix + id.to_s + "/#{span}/#{time.to_i}" })
    end
    ids.each_with_index do |id, index|
      res[index] = (res[index] || rebuild_accepted_submissions(id, now, span)).to_i
    end
    res
  end

  def self.attempted_submissions(ids, now, span)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:user_attempted_submissions]
    if span == 'all'
      res = $redis.mget(ids.map { |id| prefix + id.to_s })
    else
      time, dummy = get_time_and_expire now, span
      res = $redis.mget(ids.map { |id| prefix + id.to_s + "/#{span}/#{time.to_i}" })
    end
    ids.each_with_index do |id, index|
      res[index] = (res[index] || rebuild_attempted_submissions(id, now, span)).to_i
    end
    res
  end

  def self.accepted_problems(ids, now, span)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:user_accepted_problem_ids]
    if span == 'all'
      res = $redis.multi do |multi|
        ids.each { |id| multi.scard(prefix + id.to_s) }
      end
    else
      time, dummy = get_time_and_expire now, span
      res = $redis.multi do |multi|
        ids.each { |id| multi.scard(prefix + id.to_s + "/#{span}/#{time.to_i}") }
      end
    end
    ids.each_with_index do |id, index|
      res[index] = res[index] != 0 ? res[index] - 1 : rebuild_accepted_problem_ids(id, now, span).size
    end
    res
  end

  def self.attempted_problems(ids, now, span)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:user_attempted_problem_ids]
    if span == 'all'
      res = $redis.multi do |multi|
        ids.each { |id| multi.scard(prefix + id.to_s) }
      end
    else
      time, dummy = get_time_and_expire now, span
      res = $redis.multi do |multi|
        ids.each { |id| multi.scard(prefix + id.to_s + "/#{span}/#{time.to_i}") }
      end
    end
    ids.each_with_index do |id, index|
      res[index] = res[index] != 0 ? res[index] - 1 : rebuild_attempted_problem_ids(id, now, span).size
    end
    res
  end

  def self.accepted_problem_ids(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_accepted_problem_ids] + id.to_s
    unless span == 'all'
      time, dummy = get_time_and_expire now, span
      key = key + "/#{span}/#{time.to_i}"
    end
    rebuild_accepted_problem_ids(id, now, span) unless $redis.exists(key)
    res = $redis.smembers(key).map(&:to_i)
    res.delete(-1)
    res
  end

  def self.attempted_problem_ids(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_attempted_problem_ids] + id.to_s
    unless span == 'all'
      time, dummy = get_time_and_expire now, span
      key = key + "/#{span}/#{time.to_i}"
    end
    rebuild_attempted_problem_ids(id, now, span) unless $redis.exists(key)
    res = $redis.smembers(key).map(&:to_i)
    res.delete(-1)
    res
  end

  def self.new_accepted_submission(user_id, problem_id, submit_time)
    %w{all year month week day}.each do |span|
      key1 = APP_CONFIG.redis_namespace[:user_accepted_submissions] + user_id.to_s
      key2 = APP_CONFIG.redis_namespace[:user_accepted_problem_ids] + user_id.to_s
      unless span == 'all'
        time, dummy = get_time_and_expire submit_time, span
        key1 = key1 + "/#{span}/#{time.to_i}"
        key2 = key2 + "/#{span}/#{time.to_i}"
      end

      $redis.watch(key1)
      if $redis.exists(key1)
        unless $redis.multi { |multi| multi.incr(key1) }
          rebuild_accepted_submissions(user_id, submit_time, span)
        end
      else
        $redis.unwatch
        rebuild_accepted_submissions(user_id, submit_time, span)
      end

      loop do
        $redis.watch(key2)
        unless $redis.exists(key2)
          $redis.unwatch
          rebuild_accepted_problem_ids(user_id, submit_time, span)
          break
        end
        break if $redis.multi { |multi| multi.sadd(key2, problem_id) }
      end

      update_rank_list(user_id, submit_time, span)
    end
  end

  def self.new_attempted_submission(user_id, problem_id, submit_time)
    %w{all year month week day}.each do |span|
      key1 = APP_CONFIG.redis_namespace[:user_attempted_submissions] + user_id.to_s
      key2 = APP_CONFIG.redis_namespace[:user_attempted_problem_ids] + user_id.to_s
      unless span == 'all'
        time, dummy = get_time_and_expire submit_time, span
        key1 = key1 + "/#{span}/#{time.to_i}"
        key2 = key2 + "/#{span}/#{time.to_i}"
      end

      $redis.watch(key1)
      if $redis.exists(key1)
        unless $redis.multi { |multi| multi.incr(key1) }
          rebuild_attempted_submissions(user_id, submit_time, span)
        end
      else
        $redis.unwatch
        rebuild_attempted_submissions(user_id, submit_time, span)
      end

      loop do
        $redis.watch(key2)
        unless $redis.exists(key2)
          $redis.unwatch
          rebuild_attempted_problem_ids(user_id, submit_time, span)
          break
        end
        break if $redis.multi { |multi| multi.sadd(key2, problem_id) }
      end
    end
  end

  def self.get_handles(ids)
    return [] if ids.empty?
    key = APP_CONFIG.redis_namespace[:user_handles_hash]
    $redis.hmget(key, ids)
  end

  def self.refresh_stat_cache(id)
    now = Time.now
    %w{all year month week day}.each do |span|
      rebuild_accepted_submissions id, now, span
      rebuild_attempted_submissions id, now, span
      rebuild_accepted_problem_ids id, now, span
      rebuild_attempted_problem_ids id, now, span
      update_rank_list id, now, span
    end
  end

  def self.clear_stat_cache(ids)
    now = Time.now
    $redis.multi do |multi|
      %w{all year month week day}.each do |span|
        ids.each do |id|
          suffix = ''
          unless span == 'all'
            time, dummy = get_time_and_expire(now, span)
            suffix = "/#{span}/#{time.to_i}"
          end
          multi.del(APP_CONFIG.redis_namespace[:user_accepted_submissions] + id.to_s + suffix)
          multi.del(APP_CONFIG.redis_namespace[:user_attempted_submissions] + id.to_s + suffix)
          multi.del(APP_CONFIG.redis_namespace[:user_accepted_problem_ids] + id.to_s + suffix)
          multi.del(APP_CONFIG.redis_namespace[:user_attempted_problem_ids] + id.to_s + suffix)
        end
        key = APP_CONFIG.redis_namespace[:user_rank_list]
        unless span == 'all'
          time, dummy = get_time_and_expire(now, span)
          key = key + "#{span}/#{time.to_i}"
        end
        multi.del(key)
      end
    end
  end

  def self.update_rank_list(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_rank_list]
    unless span == 'all'
      time, dummy = get_time_and_expire now, span
      key = key + "#{span}/#{time.to_i}"
    end
    loop do
      $redis.watch(key)
      unless $redis.exists(key)
        $redis.unwatch
        rebuild_rank_list(now, span)
        break
      end
      score = accepted_problems([id], now, span).first
      break if $redis.multi do |multi|
        if score > 0
          multi.zadd(key, score, id)
        else
          multi.zrem(key, id)
        end
      end
    end
  end

  def self.get_avatar_url(handles, style)
    return {} if handles.empty?
    key = APP_CONFIG.redis_namespace[:user_avatar_url] + style
    res = {}
    $redis.hmget(key, handles).each_with_index do |url, index|
      res[handles[index]] = url
    end
    res
  end

  def self.add_user(user)
    key = APP_CONFIG.redis_namespace[:user_handles_hash]
    $redis.hset(key, user.id, user.handle)
    user.refresh_avatar_url
    add_handle_index(:user_index, user.handle)
    add_handle_index(:normal_user_index, user.handle)
  end

  def self.block_user(user)
    user.update_attribute :blocked, true
    remove_handle_index(:user_index, user.handle)
    remove_handle_index(:normal_user_index, user.handle) if user.role == 'normal_user'
  end

  def self.unblock_user(user)
    user.update_attribute :blocked, false
    add_handle_index(:user_index, user.handle)
    add_handle_index(:normal_user_index, user.handle) if user.role == 'normal_user'
  end

  def self.rank_list_count(now, span)
    key = APP_CONFIG.redis_namespace[:user_rank_list]
    unless span == 'all'
      time, dummy = get_time_and_expire now, span
      key = key + "#{span}/#{time.to_i}"
    end
    rebuild_rank_list(now, span) unless $redis.exists(key)
    $redis.zcard(key) - 1
  end

  def self.rank_list(now, span, page, page_size)
    key = APP_CONFIG.redis_namespace[:user_rank_list]
    unless span == 'all'
      time, dummy = get_time_and_expire now, span
      key = key + "#{span}/#{time.to_i}"
    end
    rebuild_rank_list(now, span) unless $redis.exists(key)
    ids = $redis.zrevrange(key, (page - 1) * page_size, page * page_size - 1).map(&:to_i)
    ids.pop if ids.last == -1
    list = ids.map { |id| OpenStruct.new(id: id) }
    get_handles(ids).each_with_index { |x, i| list[i].handle = x }
    accepted_problems(ids, now, span).each_with_index { |x, i| list[i].accepted_problems = x }
    attempted_problems(ids, now, span).each_with_index { |x, i| list[i].attempted_problems = x }
    accepted_submissions(ids, now, span).each_with_index { |x, i| list[i].accepted_submissions = x }
    attempted_submissions(ids, now, span).each_with_index { |x, i| list[i].attempted_submissions = x }
    list
  end

  def self.add_handle_index(index_name, handle)
    key = APP_CONFIG.redis_namespace[index_name.to_sym]
    handle.length.times do |x|
      $redis.sadd(key + handle[0..x].downcase, handle)
    end
  end

  def self.remove_handle_index(index_name, handle)
    key = APP_CONFIG.redis_namespace[index_name.to_sym]
    handle.length.times do |x|
      $redis.srem(key + handle[0..x].downcase, handle)
    end
  end

  def self.init_user_avatar_url
    key = APP_CONFIG.redis_namespace[:user_avatar_url]
    return if $redis.exists(key)
    $redis.set(key, 1)
    User.all.each { |user| user.refresh_avatar_url }
  end

  def self.init_handles_hash
    key = APP_CONFIG.redis_namespace[:user_handles_hash]
    return if $redis.exists(key)
    $redis.watch(key)
    $redis.multi do |multi|
      multi.del(key)
      User.all.each { |user| multi.hset(key, user.id, user.handle) }
    end
  end

  def self.init_user_index
    key = APP_CONFIG.redis_namespace[:user_index]
    return if $redis.exists(key)
    $redis.set(key, 1)
    User.where('NOT blocked').each { |user| add_handle_index :user_index, user.handle }
  end

  def self.init_normal_user_index
    key = APP_CONFIG.redis_namespace[:normal_user_index]
    return if $redis.exists(key)
    $redis.set(key, 1)
    User.where("NOT blocked AND role = 'normal_user'").each { |user| add_handle_index :normal_user_index, user.handle }
  end

  private
  def self.get_time_and_expire(now, span)
    case span
      when 'year'
        time = now.beginning_of_year
        expire = now.end_of_year
      when 'month'
        time = now.beginning_of_month
        expire = now.end_of_month
      when 'week'
        time = now.beginning_of_week
        expire = now.end_of_week
      when 'day'
        time = now.beginning_of_day
        expire = now.end_of_day
    end
    tmp = Time.now + 600
    expire = tmp if expire < tmp
    [time, expire]
  end

  def self.rebuild_accepted_submissions(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_accepted_submissions] + id.to_s
    loop do
      if span == 'all'
        $redis.watch(key)
        value = Submission.where('user_id = :user_id AND score = 100 AND NOT hidden', user_id: id).count
        return value if $redis.multi { |multi| multi.set(key, value) }
      else
        time, expire = get_time_and_expire now, span
        key = key + "/#{span}/#{time.to_i}"
        $redis.watch(key)
        value = Submission.where('user_id = :user_id AND score = 100 AND NOT hidden AND created_at >= :time', user_id: id, time: time).count
        return value if $redis.multi do |multi|
          multi.set(key, value)
          multi.expireat(key, expire.to_i)
        end
      end
    end
  end

  def self.rebuild_attempted_submissions(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_attempted_submissions] + id.to_s
    loop do
      if span == 'all'
        $redis.watch(key)
        value = Submission.where("user_id = :user_id AND status = 'judged' AND NOT hidden", user_id: id).count
        return value if $redis.multi { |multi| multi.set(key, value) }
      else
        time, expire = get_time_and_expire now, span
        key = key + "/#{span}/#{time.to_i}"
        $redis.watch(key)
        value = Submission.where("user_id = :user_id AND status = 'judged' AND NOT hidden AND created_at >= :time", user_id: id, time: time).count
        return value if $redis.multi do |multi|
          multi.set(key, value)
          multi.expireat(key, expire.to_i)
        end
      end
    end
  end

  def self.rebuild_accepted_problem_ids(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_accepted_problem_ids] + id.to_s
    loop do
      if span == 'all'
        $redis.watch(key)
        value = Submission.select('DISTINCT(problem_id)').
            where('user_id = :user_id AND score = 100 AND NOT hidden', user_id: id).map(&:problem_id)
        return value if $redis.multi do |multi|
          multi.del(key)
          multi.sadd(key, -1)
          multi.sadd(key, value) unless value.empty?
        end
      else
        time, expire = get_time_and_expire now, span
        key = key + "/#{span}/#{time.to_i}"
        $redis.watch(key)
        value = Submission.select('DISTINCT(problem_id)').
            where('user_id = :user_id AND score = 100 AND NOT hidden AND created_at >= :time', user_id: id, time: time).
            map(&:problem_id)
        return value if $redis.multi do |multi|
          multi.del(key)
          multi.sadd(key, -1)
          multi.sadd(key, value) unless value.empty?
          multi.expireat(key, expire.to_i)
        end
      end
    end
  end

  def self.rebuild_attempted_problem_ids(id, now, span)
    key = APP_CONFIG.redis_namespace[:user_attempted_problem_ids] + id.to_s
    loop do
      if span == 'all'
        $redis.watch(key)
        value = Submission.select('DISTINCT(problem_id)').
            where("user_id = :user_id AND status = 'judged' AND NOT hidden", user_id: id).map(&:problem_id)
        return value if $redis.multi do |multi|
          multi.del(key)
          multi.sadd(key, -1)
          multi.sadd(key, value) unless value.empty?
        end
      else
        time, expire = get_time_and_expire now, span
        key = key + "/#{span}/#{time.to_i}"
        $redis.watch(key)
        value = Submission.select('DISTINCT(problem_id)').
            where("user_id = :user_id AND status = 'judged' AND NOT hidden AND created_at >= :time", user_id: id, time: time).
            map(&:problem_id)
        return value if $redis.multi do |multi|
          multi.del(key)
          multi.sadd(key, -1)
          multi.sadd(key, value) unless value.empty?
          multi.expireat(key, expire.to_i)
        end
      end
    end
  end

  def self.rebuild_rank_list(now, span)
    key = APP_CONFIG.redis_namespace[:user_rank_list]
    loop do
      if span == 'all'
        $redis.watch(key)
        return if $redis.multi do |multi|
          multi.del(key)
          multi.zadd(key, -1, -1)
          connection.execute(
              %q{
                 SELECT user_id AS id, COUNT(DISTINCT problem_id) AS accepted_problems
                 FROM submissions
                 WHERE score = 100 AND NOT hidden
                 GROUP BY user_id
              },
          ).each { |row| multi.zadd(key, row['accepted_problems'], row['id']) }
        end
      else
        time, expire = get_time_and_expire now, span
        key = key + "#{span}/#{time.to_i}"
        return if $redis.multi do |multi|
          multi.del(key)
          multi.zadd(key, -1, -1)
          connection.execute(sanitize_sql_array([
              %q{
                 SELECT user_id AS id, COUNT(DISTINCT problem_id) AS accepted_problems
                 FROM submissions
                 WHERE score = 100 AND NOT hidden AND created_at >= :time
                 GROUP BY user_id
              },
              time: time
          ])).each { |row| multi.zadd(key, row['accepted_problems'], row['id']) }
          multi.expireat(key, expire.to_i)
        end
      end
    end
  end
end
