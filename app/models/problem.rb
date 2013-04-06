require 'ostruct'
require 'json'
require 'judge_config'
require 'fileutils'

include JudgeConfig

class Problem < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  has_many :sample_test_datas, order: 'case_no ASC'
  has_and_belongs_to_many :tags, order: 'name ASC'
  has_one :content, class_name: 'ProblemContent', autosave: true

  attr_accessible :status
  attr_accessible :title
  attr_accessible :source
  attr_accessible :content
  attr_accessible :test_data_timestamp
  attr_accessible :tags
  attr_accessible :sample_test_datas

  validates :title, presence: true
  validates :title, length: { maximum: 100 }
  validates :source, length: { maximum: 100 }

  def test_attachment_file(zip_file)
    dir = nil
    loop do
      dir = Rails.root.join('tmp', 'upload', (0...20).map { ('a'..'z').to_a[rand(26)] }.join)
      break unless dir.exist?
    end
    dir.mkpath
    File.open(dir + 'attachment.zip', 'wb') { |f| f.write(zip_file.read) }
    unless system("unzip -q -t #{dir + 'attachment.zip'}")
      dir.rmtree
      return nil
    end
    dir
  end

  def unzip_attachment_file(dir)
    dest_dir = Rails.root.join('public', 'attachment', id.to_s)
    dest_dir.rmtree if dest_dir.exist?
    dest_dir.mkpath
    system("unzip -o -q #{dir + 'attachment.zip'} -d #{dest_dir}")
    dir.rmtree
  end

  def unzip_test_data_file(zip_file)
    dir = nil
    loop do
      dir = Rails.root.join('tmp', 'upload', (0...20).map { ('a'..'z').to_a[rand(26)] }.join)
      break unless dir.exist?
    end
    dir.mkpath
    data_dir = dir.join('data')
    File.open(dir + 'data.zip', 'wb') { |f| f.write(zip_file.read) }
    unless system("unzip -o -q #{dir + 'data.zip'} -d #{data_dir}")
      dir.rmtree
      return { errors: I18n.t('problems.upload_test_data.cannot_unzip') }
    end
    begin
      config = JudgeConfig::parse_config dir.join('data')
    rescue JudgeConfig::ConfigNotExist
      dir.rmtree
      return { errors: I18n.t('problems.upload_test_data.config_not_exist') }
    rescue JudgeConfig::InvalidConfig
      dir.rmtree
      return { errors: I18n.t('problems.upload_test_data.invalid_config') }
    end
    sample_test_datas.destroy_all
    config[:sample_test_data].each_with_index do |data, index|
      input = ''
      output = ''
      File.open(dir.join('data', data[:input_file])) { |f| input = f.read }
      File.open(dir.join('data', data[:output_file])) { |f| output = f.read }
      sample_test_datas.create input: input, output: output, case_no: index
    end
    Rails.root.join('test_data', id.to_s).mkpath
    FileUtils.cp_r dir.join('data.zip'), Rails.root.join('test_data', id.to_s), remove_destination: true
    update_attribute :test_data_timestamp, Time.now
    dir.rmtree
    config
  end

  def clear_test_data_path
    Rails.root.join('test_data', id.to_s).rmtree
  end

  def update_tags(tag_list)
    return nil if tag_list.sort == tags.all.map(&:name).sort
    Tag.clear_cache
    res = []
    Tag.transaction do
      connection.execute('LOCK TABLE tags')
      tags.each { |tag| res << tag.id }
      tags.delete_all
      exist_tags = Hash[Tag.where('name IN (:tag_list)', tag_list: tag_list).map { |tag| [tag.name, tag] }]
      tag_list.each do |name|
        if exist_tags[name]
          tags << exist_tags[name]
          res << exist_tags[name].id
        else
          tags << Tag.create(name: name)
        end
      end
      save
    end
    res
  end

  def rejudge
    submissions = nil
    user_ids = nil
    Submission.transaction do
      connection.execute('LOCK TABLE submissions')
      submissions = Submission.where("problem_id = :problem_id AND status <> 'waiting'", problem_id: id).order('id ASC')
      ids = submissions.map(&:id)
      user_ids = Submission.select('DISTINCT(user_id)').where("id IN (:ids)", ids: ids).map(&:user_id)
      Submission.update_all("status = 'waiting', time_used = NULL, memory_used = NULL, score = NULL", ['id IN (:ids)', ids: ids])
    end
    User.clear_stat_cache user_ids
    Problem.refresh_stat_cache id
    Problem.remove_hot_problems
    submissions.each do |submission|
      key = APP_CONFIG.redis_namespace[:waiting_submissions] + submission.platform
      $redis.rpush(key, submission.id)
    end
  end

  def accepted_users
    Problem.accepted_users([id]).first
  end

  def attempted_users
    Problem.attempted_users([id]).first
  end

  def accepted_submissions
    Problem.accepted_submissions([id]).first
  end

  def attempted_submissions
    Problem.attempted_submissions([id]).first
  end

  def average_score
    Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).
        average(:score) || 0.0
  end

  def self.accepted_users(ids)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:problem_accepted_user_ids]
    res = $redis.multi do |multi|
      ids.each { |id| multi.scard(prefix + id.to_s) }
    end
    ids.each_with_index do |id, index|
      res[index] = res[index] != 0 ? res[index] - 1 : rebuild_accepted_user_ids(id).size
    end
    res
  end

  def self.attempted_users(ids)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:problem_attempted_user_ids]
    res = $redis.multi do |multi|
      ids.each { |id| multi.scard(prefix + id.to_s) }
    end
    ids.each_with_index do |id, index|
      res[index] = res[index] != 0 ? res[index] - 1 : rebuild_attempted_user_ids(id).size
    end
    res
  end

  def self.accepted_submissions(ids)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:problem_accepted_submissions]
    res = $redis.mget(ids.map { |id| prefix + id.to_s })
    ids.each_with_index do |id, index|
      res[index] = (res[index] || rebuild_accepted_submissions(id)).to_i
    end
    res
  end

  def self.attempted_submissions(ids)
    return [] if ids.empty?
    prefix = APP_CONFIG.redis_namespace[:problem_attempted_submissions]
    res = $redis.mget(ids.map { |id| prefix + id.to_s })
    ids.each_with_index do |id, index|
      res[index] = (res[index] || rebuild_attempted_submissions(id)).to_i
    end
    res
  end

  def self.new_accepted_submission(problem_id, user_id, submit_time)
    key = APP_CONFIG.redis_namespace[:problem_accepted_submissions] + problem_id.to_s
    $redis.watch(key)
    if $redis.exists(key)
      unless $redis.multi { |multi| multi.incr(key) }
        rebuild_accepted_submissions(problem_id)
      end
    else
      $redis.unwatch
      rebuild_accepted_submissions(problem_id)
    end

    key = APP_CONFIG.redis_namespace[:problem_accepted_user_ids] + problem_id.to_s
    loop do
      $redis.watch(key)
      unless $redis.exists(key)
        $redis.unwatch
        rebuild_accepted_user_ids(problem_id)
        break
      end
      break if $redis.multi { |multi| multi.sadd(key, user_id) }
    end
  end

  def self.new_attempted_submission(problem_id, user_id, submit_time)
    key = APP_CONFIG.redis_namespace[:problem_attempted_submissions] + problem_id.to_s
    $redis.watch(key)
    if $redis.exists(key)
      unless $redis.multi { |multi| multi.incr(key) }
        rebuild_attempted_submissions(problem_id)
      end
    else
      $redis.unwatch
      rebuild_attempted_submissions(problem_id)
    end

    key = APP_CONFIG.redis_namespace[:problem_attempted_user_ids] + problem_id.to_s
    loop do
      $redis.watch(key)
      unless $redis.exists(key)
        $redis.unwatch
        rebuild_attempted_user_ids(problem_id)
        break
      end
      break if $redis.multi { |multi| multi.sadd(key, user_id) }
    end

    key = APP_CONFIG.redis_namespace[:problem_hot_problems] + "/#{submit_time.beginning_of_day.to_i}"
    $redis.watch(key)
    if $redis.exists(key)
      unless $redis.multi { |multi| $redis.zincrby(key, 1, problem_id.to_s) }
        rebuild_hot_problems(submit_time)
      end
    else
      $redis.unwatch
      rebuild_hot_problems(submit_time)
    end
  end

  def self.get_titles(ids)
    return [] if ids.empty?
    key = APP_CONFIG.redis_namespace[:problem_titles_hash]
    $redis.hmget(key, ids)
  end

  def self.add_title(id, title)
    key = APP_CONFIG.redis_namespace[:problem_titles_hash]
    $redis.hset(key, id, title)
  end

  def self.refresh_stat_cache(id)
    rebuild_accepted_submissions id
    rebuild_attempted_submissions id
    rebuild_accepted_user_ids id
    rebuild_attempted_user_ids id
  end

  def has_view_privilege(user)
    role = user ? user.role : 'normal_user'
    return false if status == 'hidden' && role != 'admin'
    return false if status == 'advanced' && role == 'normal_user'
    true
  end

  def self.count_for_role(role, tags)
    if tags.empty?
      Rails.cache.fetch("model/problem/count_for_role/#{role}") do
        Problem.where('status IN (:set)', set: status_set_for_role(role)).count
      end
    else
      fetch_if(tags.size == 1, "model/problem/count_for_role/#{role}/#{tags.first}") do
        connection.execute(sanitize_sql_array([
            %q{
               SELECT COUNT(*)
               FROM problems AS x
               INNER JOIN (
                   SELECT problem_id
                   FROM problems_tags
                   WHERE tag_id IN (:tag_ids)
                   GROUP BY problem_id
                   HAVING COUNT(*) = :tags_size
               ) AS y ON y.problem_id = x.id
               WHERE x.status IN (:set)
            },
            set: status_set_for_role(role), tag_ids: tags, tags_size: tags.size
        ])).first['count'].to_i
      end
    end
  end

  def self.list_for_role(role, tags, page, page_size)
    if tags.empty?
      list = Rails.cache.fetch("model/problem/list/#{role}/#{page}") do
        connection.execute(sanitize_sql_array([
            %q{
               SELECT id, title, source, status
               FROM problems
               WHERE status IN (:set)
               ORDER BY id
               OFFSET :offset LIMIT :limit
            },
            set: status_set_for_role(role),
            offset: (page - 1) * page_size, limit: page_size
        ])).map do |row|
          OpenStruct.new(
              id: row['id'].to_i,
              title: row['title'],
              source: row['source'],
              status: row['status']
          )
        end
      end
    else
      list = fetch_if(tags.size == 1, "model/problem/list/#{role}/#{page}/#{tags.first}") do
        connection.execute(sanitize_sql_array([
            %q{
               SELECT x.id, x.title, x.source, x.status
               FROM problems AS x
               INNER JOIN (
                   SELECT problem_id
                   FROM problems_tags
                   WHERE tag_id IN (:tag_ids)
                   GROUP BY problem_id
                   HAVING COUNT(*) = :tags_size
               ) AS y ON y.problem_id = x.id
               WHERE x.status IN (:set)
               ORDER BY x.id
               OFFSET :offset LIMIT :limit
            },
            set: status_set_for_role(role), tag_ids: tags, tags_size: tags.size,
            offset: (page - 1) * page_size, limit: page_size
        ])).map do |row|
          OpenStruct.new(
              id: row['id'].to_i,
              title: row['title'],
              source: row['source'],
              status: row['status']
          )
        end
      end
    end
    ids = list.map(&:id)
    accepted_submissions_list = accepted_submissions ids
    attempted_submissions_list = attempted_submissions ids
    list.each_with_index do |problem, index|
      problem.accepted_submissions = accepted_submissions_list[index]
      problem.attempted_submissions = attempted_submissions_list[index]
    end
    list
  end

  def self.clear_list_cache(tag_id = nil)
    page_size = APP_CONFIG.page_size[:problems_list]
    %w{normal_user advanced_user admin}.each do |role|
      if tag_id
        Rails.cache.delete "model/problem/count_for_role/#{role}/#{tag_id}"
        total_page = (count_for_role(role, [tag_id]) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          Rails.cache.delete "model/problem/list/#{role}/#{page}/#{tag_id}"
        end
      else
        Rails.cache.delete "model/problem/count_for_role/#{role}"
        total_page = (count_for_role(role, []) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          Rails.cache.delete "model/problem/list/#{role}/#{page}"
        end
      end
    end
  end

  def self.status_list_count(problem_id)
    Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: problem_id).
        count(:user_id, distinct: true)
  end

  def self.status_list(problem_id, page, page_size)
    connection.execute(sanitize_sql_array([
        %q{
           SELECT y.id, y.share, z.handle, x.count, y.score, y.time_used, y.memory_used,
                  y.language, y.platform, y.code_length, y.code_size, y.created_at
           FROM (
               SELECT user_id, COUNT(*) AS count
               FROM submissions
               WHERE problem_id = :problem_id AND status = 'judged' AND NOT hidden
               GROUP BY user_id
           ) AS x
           INNER JOIN (
               SELECT id, share, user_id, score, time_used, memory_used, language, platform, code_length, code_size,
                      created_at, RANK() OVER (
                                      PARTITION BY user_id
                                      ORDER BY score DESC, time_used ASC, memory_used ASC, code_size ASC, id ASC
                                  ) AS pos
               FROM submissions
               WHERE problem_id = :problem_id AND status = 'judged' AND NOT hidden
           ) AS y ON y.pos = 1 AND y.user_id = x.user_id
           INNER JOIN users AS z ON z.id = x.user_id
           ORDER BY y.score DESC, y.time_used ASC, y.memory_used ASC, y.code_size ASC, y.id ASC
           OFFSET :offset LIMIT :limit
        },
        problem_id: problem_id, offset: (page - 1) * page_size, limit: page_size
    ])).map do |row|
      OpenStruct.new(
          submission_id: row['id'].to_i,
          user_handle: row['handle'],
          tried_times: row['count'].to_i,
          score: row['score'].to_i,
          time_used: row['time_used'].to_i,
          memory_used: row['memory_used'].to_i,
          language: row['language'],
          platform: row['platform'],
          code_length: row['code_length'].to_i,
          code_size: row['code_size'].to_i,
          created_at: Time.parse(row['created_at'] + ' UTC'),
          share: row['share'] == 't'
      )
    end
  end

  def self.init_titles_hash
    key = APP_CONFIG.redis_namespace[:problem_titles_hash]
    return if $redis.exists(key)
    $redis.watch(key)
    $redis.multi do |multi|
      multi.del(key)
      Problem.all.each { |problem| multi.hset(key, problem.id, problem.title) }
    end
  end

  def self.hot_problems(now, limit)
    key = APP_CONFIG.redis_namespace[:problem_hot_problems] + "#{now.beginning_of_day.to_i}"
    rebuild_hot_problems(now) unless $redis.exists(key)
    list = $redis.zrevrange(key, 0, limit - 1, with_scores: true).map do |entry|
      OpenStruct.new(id: entry[0].to_i, submissions: entry[1].to_i)
    end
    list.pop if list.last.id == -1
    get_titles(list.map(&:id)).each_with_index { |title, index| list[index].title = title }
    list
  end

  def self.remove_hot_problems
    key = APP_CONFIG.redis_namespace[:problem_hot_problems] + "#{Time.now.beginning_of_day.to_i}"
    $redis.del(key)
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

  def self.rebuild_accepted_submissions(id)
    key = APP_CONFIG.redis_namespace[:problem_accepted_submissions] + id.to_s
    loop do
      $redis.watch(key)
      value = Submission.where('problem_id = :problem_id AND score = 100 AND NOT hidden', problem_id: id).count
      return value if $redis.multi { |multi| multi.set(key, value) }
    end
  end

  def self.rebuild_attempted_submissions(id)
    key = APP_CONFIG.redis_namespace[:problem_attempted_submissions] + id.to_s
    loop do
      $redis.watch(key)
      value = Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).count
      return value if $redis.multi { |multi| multi.set(key, value) }
    end
  end

  def self.rebuild_accepted_user_ids(id)
    key = APP_CONFIG.redis_namespace[:problem_accepted_user_ids] + id.to_s
    loop do
      $redis.watch(key)
      value = Submission.select('DISTINCT(user_id)').
          where('problem_id = :problem_id AND score = 100 AND NOT hidden', problem_id: id).map(&:user_id)
      return value if $redis.multi do |multi|
        multi.del(key)
        multi.sadd(key, -1)
        multi.sadd(key, value) unless value.empty?
      end
    end
  end

  def self.rebuild_attempted_user_ids(id)
    key = APP_CONFIG.redis_namespace[:problem_attempted_user_ids] + id.to_s
    loop do
      $redis.watch(key)
      value = Submission.select('DISTINCT(user_id)').
          where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).map(&:user_id)
      return value if $redis.multi do |multi|
        multi.del(key)
        multi.sadd(key, -1)
        multi.sadd(key, value) unless value.empty?
      end
    end
  end

  def self.rebuild_hot_problems(now)
    key = APP_CONFIG.redis_namespace[:problem_hot_problems]
    time = now.beginning_of_day
    expire = now.end_of_day
    tmp = Time.now + 600
    expire = tmp if expire < tmp
    key = key + "#{time.to_i}"
    loop do
      $redis.watch(key)
      return if $redis.multi do |multi|
        multi.del(key)
        multi.zadd(key, -1, -1)
        connection.execute(sanitize_sql_array([
          %q{
             SELECT problem_id AS id, COUNT(*) AS submissions
             FROM submissions
             WHERE created_at >= :time AND status = 'judged' AND NOT hidden
             GROUP BY problem_id
          },
          time: time
        ])).each { |x| multi.zadd(key, x['submissions'], x['id']) }
        multi.expireat(key, expire.to_i)
      end
    end
  end
end
