require 'ostruct'
require 'json'
require 'judge_config'
require 'fileutils'

include JudgeConfig

class Problem < ActiveRecord::Base
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
      tags.delete_all
      tag_list.each do |name|
        tag = Tag.lock(true).find_by_name name
        unless tag
          tag = Tag.create name: name
        end
        tags << tag
      end
      save
      Tag.lock(true).all.each do |tag|
        tag.delete if tag.problems.size == 0
      end
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
    Submission.where("problem_id = :problem_id AND score = 100 AND status = 'judged' AND NOT hidden", problem_id: id).
        count
  end

  def attempted_submissions
    Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).count
  end

  def average_score
    res = Submission.where("problem_id = :problem_id AND status = 'judged' AND NOT hidden", problem_id: id).
        average(:score)
    res = 0 unless res
    res
  end

  def self.count_for_role(role, tags)
    if tags.empty?
      Problem.where('status IN (:set)', set: status_set_for_role(role)).count
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
      list = connection.execute(sanitize_sql_array([
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
    else
      list = connection.execute(sanitize_sql_array([
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
    ids = list.map { |x| x.id }
    accepted_submissions = Hash[connection.execute(sanitize_sql_array([
        %q{
           SELECT problem_id AS id, COUNT(*) AS count
           FROM submissions
           WHERE problem_id IN (:ids) AND score = 100 AND status = 'judged' AND NOT hidden
           GROUP BY problem_id
        },
        ids: ids
    ])).map { |row| [row['id'].to_i, row['count'].to_i] }]
    attempted_submissions = Hash[connection.execute(sanitize_sql_array([
        %q{
           SELECT problem_id AS id, COUNT(*) AS count
           FROM submissions
           WHERE problem_id IN (:ids) AND status = 'judged' AND NOT hidden
           GROUP BY problem_id
        },
        ids: ids
    ])).map { |row| [row['id'].to_i, row['count'].to_i] }]
    list.each do |problem|
      problem.accepted_submissions = accepted_submissions[problem.id] || 0
      problem.attempted_submissions = attempted_submissions[problem.id] || 0
    end
    list
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
