class SubmissionsController < ApplicationController
  before_filter :require_login, only: [ :create, :share ]
  before_filter :require_judge_client, only: [ :get_waiting, :receive_result ]
  before_filter :require_admin, only: [ :show, :hide, :rejudge ]
  skip_before_filter :inspect_login_cookie, only: [ :get_waiting, :receive_result ]
  skip_before_filter :inspect_current_user, only: [ :get_waiting, :receive_result ]
  before_filter :inspect_submit_interval, only: [ :create ]

  def result
    @submission = Submission.find_by_id params[:submission_id]
    raise AppExceptions::InvalidSubmissionId unless @submission
    if @submission.hidden
      raise AppExceptions::NoPrivilegeError unless @current_user && @current_user.role == 'admin'
    end
    unless @submission.share || @current_user && (@submission.user.id == @current_user.id || @current_user.role == 'admin')
      raise AppExceptions::NoPrivilegeError
    end
    @result = JSON.parse(@submission.result, symbolize_names: true) if @submission.status == 'judged'
    @submission_active = true
    @title = t('submissions.result.submission_result', id: @submission.id)
  end

  def show
    submission = Submission.find_by_id params[:submission_id]
    raise AppExceptions::InvalidSubmissionId unless submission
    submission.update_attribute :hidden, false
    redirect_to :back, notice: t('submissions.operation.success')
  end

  def hide
    submission = Submission.find_by_id params[:submission_id]
    raise AppExceptions::InvalidSubmissionId unless submission
    submission.update_attribute :hidden, true
    redirect_to :back, notice: t('submissions.operation.success')
  end

  def share
    @submission = Submission.find_by_id params[:submission_id]
    raise AppExceptions::InvalidSubmissionId unless @submission
    if @submission.hidden
      raise AppExceptions::NoPrivilegeError unless @current_user && @current_user.role == 'admin'
    end
    raise AppExceptions::NoPrivilegeError unless @submission.user.id == @current_user.id
    @submission.update_attribute :share, true
    redirect_to :back, notice: t('submissions.operation.success')
  end

  def rejudge
    submission = Submission.find_by_id params[:submission_id]
    raise AppExceptions::InvalidSubmissionId unless submission
    Submission.transaction do
      submission.lock!.update_attributes(
          status: 'waiting',
          score: nil,
          time_used: nil,
          memory_used: nil,
          result: nil
      )
    end
    redirect_to :back, notice: t('submissions.operation.success')
  end

  def download
    submission = Submission.find_by_id params[:submission_id]
    raise AppExceptions::InvalidSubmissionId unless submission
    if submission.hidden
      raise AppExceptions::NoPrivilegeError unless @current_user && @current_user.role == 'admin'
    end
    unless submission.share || @current_user && (submission.user.id == @current_user.id || @current_user.role == 'admin')
      raise AppExceptions::NoPrivilegeError
    end
    send_data submission.program, filename: 'Main.' + submission.language
  end

  def list
    @page = (params[:page] || '1').to_i
    page_size = APP_CONFIG.page_size[:submissions_list]
    filter = {
        handle: (params[:handle] || '').strip,
        problem_id: (params[:problem_id] || '').strip,
        min_score: (params[:min_score] || '').strip,
        max_score: (params[:max_score] || '').strip,
        languages: parse_chosen(APP_CONFIG.program_languages.keys.map(&:to_s), 'language', 'languages'),
        platforms: parse_chosen(APP_CONFIG.judge_platforms.keys.map(&:to_s), 'platform', 'platforms')
    }

    unless validate_filter filter
      @page = 1
      @is_last_page = true
      @submissions = []
      return
    end

    filter[:show_hidden] = true if @current_user && @current_user.role == 'admin'
    @submissions = Submission.filtered_list filter, @page, page_size
    if @submissions.size <= page_size
      @is_last_page = true
    else
      @submissions.pop
    end
    @submission_active = true
    @title = t 'submissions.list.submissions_list'
  end

  def create
    program = params[:program].respond_to?(:read) ? params[:program].read : ''
    problem = Problem.find_by_id(params[:problem_id])
    raise AppExceptions::InvalidProblemId unless problem
    raise AppExceptions::NoTestDataError unless problem.test_data_timestamp

    @submission = Submission.new(
        remote_ip: request.remote_ip,
        language: params[:language],
        platform: params[:platform],
        program: program,
        user: @current_user,
        problem: problem,
        code_length: program.lines.count,
        code_size: program.bytesize,
        hidden: problem.status == 'hidden'
    )
    if @submission.save
      update_submit_times
      render json: { success: true, redirect_url: submissions_list_url(choose_all: '1') }
    else
      render json: { success: false, errors: @submission.errors.to_hash }
    end
  end

  def get_waiting
    submission = nil
    Submission.transaction do
      submission = Submission.select('id, problem_id, language, program').
          where("platform = :platform AND status = 'waiting'", platform: params[:platform]).order('id ASC').lock(true).first
      submission.update_attribute :status, 'running' if submission
    end
    result = {}
    if submission
      result[:submission_id] = submission.id
      result[:problem_id] = submission.problem_id
      result[:test_data_timestamp] = Problem.select('test_data_timestamp').
          find_by_id(submission.problem_id).test_data_timestamp
      result[:language] = submission.language
      result[:program] = submission.program
    else
      result[:no_waiting_submission] = true
    end
    render json: result
  end

  def receive_result
    submission = Submission.find_by_id params[:submission_id]
    unless submission && submission.status == 'running'
      render text: 'success'
      return
    end
    result = JSON.parse params[:result], symbolize_names: true
    if result[:compile_message]
      score = 0
      Submission.transaction do
        submission.lock!.update_attributes result: params[:result], status: 'judged', score: score
      end
      render text: 'success'
      return
    end
    score = result[:score].reduce(:+)
    time_used = 0
    memory_used = 0
    result[:result].each do |test_case|
      test_case.each do |single_case|
        time_used += single_case[:time_used]
        memory_used = [memory_used, single_case[:memory_used]].max
      end
    end
    Submission.transaction do
      submission.lock!.update_attributes(
          result: params[:result],
          status: 'judged',
          score: score,
          time_used: time_used,
          memory_used: memory_used
      )
    end
    render text: 'success'
  end

  private
  def parse_chosen(keys, prefix, param_name)
    result = []
    keys.each do |x|
      if params[prefix + '_' + x] || params['choose_all']
        result << x
      end
    end
    result
  end

  def validate_filter(filter)
    unless filter[:handle].empty?
      return false unless filter[:handle] =~ /\A[a-z0-9\._]{3,20}\Z/i && User.find_by_handle(filter[:handle])
    end
    unless filter[:problem_id].empty?
      return false unless filter[:problem_id] =~ /\A\d{4}\Z/ && Problem.find_by_id(filter[:problem_id])
    end
    return false unless filter[:min_score] =~ /\A\d*\Z/
    return false unless filter[:max_score] =~ /\A\d*\Z/
    true
  end
end
