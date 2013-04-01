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
    Tag.transaction do
      connection.execute('LOCK TABLE tags')
      tags.delete_all
      exist_tags = Tag.find_by_sql([
          %q{
             SELECT x.name
             FROM tags AS x
             INNER JOIN problems_tags AS y ON x.id = y.tag_id AND y.problem_id = :problem_id
             WHERE x.name IN (:tag_list)
          },
          problem_id: id, tag_list: tag_list
      ]).map(&:name)
      tag_list.each do |name|
        tags << Tag.create(name: name) unless exist_tags.include? name
      end
      save
    end
  end

  def accepted_users
    Submission.where("problem_id = :problem_id AND score = 100 AND status = 'judged' AND NOT hidden", problem_id: id).
        count(:user_id, distinct: true)
  end

  def attempted_users
    Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).
        count(:user_id, distinct: true)
  end

  def accepted_submissions
    Rails.cache.fetch("model/problem/#{id}/accepted_submissions") do
      Submission.where("problem_id = :problem_id AND score = 100 AND status = 'judged' AND NOT hidden", problem_id: id).count
    end
  end

  def attempted_submissions
    Rails.cache.fetch("model/problem/#{id}/attempted_submissions") do
      Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).count
    end
  end

  def clear_statistics_cache
    Rails.cache.delete "model/problem/#{id}/accepted_submissions"
    Rails.cache.delete "model/problem/#{id}/attempted_submissions"
  end

  def average_score
    res = Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).
        average(:score)
    res = 0 unless res
    res
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

  def self.list_for_role(role, tags, page, page_size)
    if tags.empty?
      list = Rails.cache.fetch("model/problem/list/#{role}") do
        Problem.select('id').where('status IN (:set)', set: status_set_for_role(role)).order('id').map(&:id)
      end
      list = list[(page - 1) * page_size, page_size]
      list = [] unless list
    else
      list = connection.execute(sanitize_sql_array([
          %q{
             SELECT x.id
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
      ])).map { |row| row['id'] }
    end
    list
  end

  def self.clear_list_cache
    Rails.cache.delete 'model/problem/count_for_role/normal_user'
    Rails.cache.delete 'model/problem/count_for_role/advanced_user'
    Rails.cache.delete 'model/problem/count_for_role/admin'

    Rails.cache.delete 'model/problem/list/normal_user'
    Rails.cache.delete 'model/problem/list/advanced_user'
    Rails.cache.delete 'model/problem/list/admin'
  end

  def self.status_list_count(problem)
    Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: problem.id).
        count(:user_id, distinct: true)
  end

  def self.status_list(problem, page, page_size)
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
                                      ORDER BY score DESC, time_used ASC, memory_used ASC, code_size ASC
                                  ) AS pos
               FROM submissions
               WHERE problem_id = :problem_id AND status = 'judged' AND NOT hidden
           ) AS y ON y.pos = 1 AND y.user_id = x.user_id
           INNER JOIN users AS z ON z.id = x.user_id
           ORDER BY y.score DESC, y.time_used ASC, y.memory_used ASC, y.code_size ASC
           OFFSET :offset LIMIT :limit
        },
        problem_id: problem.id, offset: (page - 1) * page_size, limit: page_size
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

  def self.hot_problems(time, role, limit)
    connection.execute(sanitize_sql_array([
        %q{
           SELECT x.id, x.title, y.submissions
           FROM problems AS x
           INNER JOIN (
               SELECT problem_id, COUNT(*) AS submissions
               FROM submissions
               WHERE created_at >= :time AND status = 'judged' AND NOT hidden
               GROUP BY problem_id
           ) AS y ON x.id = y.problem_id
           WHERE x.status IN (:set)
           ORDER BY y.submissions DESC
           LIMIT :limit
        },
        set: status_set_for_role(role), time: time, limit: limit
    ])).map do |row|
      OpenStruct.new(
          id: row['id'].to_i,
          title: row['title'],
          submissions: row['submissions'].to_i,
      )
    end
  end

  private
  def self.status_set_for_role(role)
    set = ['normal']
    set << 'advanced' if role == 'advanced_user' || role == 'admin'
    set << 'hidden' if role == 'admin'
    set
  end
end
