class Submission < ActiveRecord::Base
  belongs_to :user
  belongs_to :problem

  has_one :detail, class_name: 'SubmissionDetail', autosave: true

  attr_accessible :remote_ip
  attr_accessible :user
  attr_accessible :problem
  attr_accessible :code_length
  attr_accessible :code_size
  attr_accessible :language
  attr_accessible :platform
  attr_accessible :score
  attr_accessible :status
  attr_accessible :time_used
  attr_accessible :memory_used
  attr_accessible :share
  attr_accessible :hidden
  attr_accessible :detail

  validates_associated :user
  validates_associated :problem

  validates :language, presence: true
  validates :platform, presence: true
  validates :code_size, inclusion: { in: 0..APP_CONFIG.program_size_limit }
  validates :language, inclusion: { in: APP_CONFIG.program_languages.keys.map(&:to_s) }
  validates :platform, inclusion: { in: APP_CONFIG.judge_platforms.keys.map(&:to_s) }

  def self.filtered_list(filter, page, page_size)
    tmp = where_str_and_params filter
    Submission.where(tmp[0], tmp[1]).order('id DESC').
        offset((page - 1) * page_size).limit(page_size + 1)
  end

  def self.init_waiting_submissions
    APP_CONFIG.judge_platforms.keys.each do |platform|
      key = APP_CONFIG.redis_namespace[:waiting_submissions] + platform.to_s
      next if $redis.exists(key)
      $redis.watch(key)
      $redis.multi do |multi|
        multi.del(key)
        ids = Submission.where("platform = :platform AND status = 'waiting'", platform: platform).order('id ASC').map(&:id)
        ids.each { |id| multi.rpush(key, id) }
      end
    end
  end

  private
  def self.where_str_and_params(filter)
    str = []
    params = {}
    unless filter[:handle].empty?
      str << 'user_id = :user_id'
      params[:user_id] = User.fetch_by_uniq_key(filter[:handle], :handle).id
    end
    unless filter[:problem_id].empty?
      str << 'problem_id = :problem_id'
      params[:problem_id] = filter[:problem_id].to_i
    end
    unless filter[:min_score].empty?
      str << 'score >= :min_score'
      params[:min_score] = filter[:min_score].to_i
    end
    unless filter[:max_score].empty?
      str << 'score <= :max_score'
      params[:max_score] = filter[:max_score].to_i
    end
    str << 'language IN (:languages)'
    params[:languages] = filter[:languages]
    str << 'platform IN (:platforms)'
    params[:platforms] = filter[:platforms]
    str << 'NOT hidden' unless filter[:show_hidden]
    str = str.join(' AND ')
    [str, params]
  end
end
