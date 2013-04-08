class ProblemsController < ApplicationController
  before_filter :require_admin, only: [ :create, :update, :edit, :upload_test_data, :rejudge ]
  before_filter :check_view_privilege, only: [ :status ]

  def show
    @problem = Problem.find_by_id! params[:problem_id]
    render 'problems/no_privilege' unless @problem.has_view_privilege(@current_user)
  end

  def status
    @problem = Problem.find_by_id! params[:problem_id]
    @page = params[:page].to_i
    @page_size = APP_CONFIG.page_size[:problem_status_list]
    @total_page = Rails.cache.fetch("model/problem/total_page/#{@problem.id}") do
      calc_total_page Problem.status_list_count(@problem.id), @page_size
    end
    validate_page_number @page, @total_page
  end

  def list
    @tag_ids = []
    @tag_hash = {}
    Tag.valid_ids.each do |id|
      if params["tag_#{id}"]
        @tag_ids << id
        @tag_hash["tag_#{id}"] = '1'
      end
    end
    raise AppExceptions::InvalidOperation if @tag_ids.size > 5

    page_size = APP_CONFIG.page_size[:problems_list]
    @role = @current_user ? @current_user.role : 'normal_user'
    @total_page = calc_total_page Problem.count_for_role(@role, @tag_ids), page_size
    if params[:page]
      @page = params[:page].to_i
      validate_page_number @page, @total_page
    elsif @tag_ids.empty? && cookies[:page_no]
      @page = cookies[:page_no].to_i
      @page = 1 unless 1 <= @page && @page <= @total_page
    else
      @page = 1
    end

    @problems = Problem.list_for_role @role, @tag_ids, @page, page_size
    if @tag_ids.empty?
      cookies[:page_no] = { value: @page.to_s, expires: 1.year.from_now, path: '/problems/list' }
    end
  end

  def create
    problem = Problem.new params[:problem]
    problem.content = ProblemContent.new params[:problem_content]
    if problem.save
      clear_list_cache
      Problem.add_title problem.id, problem.title
      render json: { success: true, redirect_url: problems_show_url(problem.id) }
    else
      render json: { success: false, errors: problem.errors.to_hash }
    end
  end

  def edit
    @problem = Problem.find_by_id! params[:problem_id]
    @tags = @problem.tags.map(&:name).join(APP_CONFIG.tags_input_separate_char)
  end

  def update
    problem = Problem.includes.find_by_id! params[:problem_id]
    need_clear_list_cache = false
    need_clear_list_cache ||= problem.title != params[:problem][:title]
    need_clear_list_cache ||= problem.source != params[:problem][:source]
    need_clear_list_cache ||= problem.status != params[:problem][:status]
    problem.attributes = params[:problem]
    problem.content.attributes = params[:problem_content]

    tags = params[:tags].split(APP_CONFIG.tags_input_separate_char)
    tags.each do |tag|
      if tag.length > 20
        return render json: { success: false, errors: { tags: t('problems.edit.tag_too_long') } }
      end
    end

    dir = nil
    if params[:attachment_file].respond_to? :read
      dir = problem.test_attachment_file params[:attachment_file]
      unless dir
        return render json: { success: false, errors: { attachment_file: t('problems.edit.cannot_unzip_attachment_file') } }
      end
    end

    if params[:program].respond_to? :read
      problem.content.program = params[:program].read
      if problem.content.program.bytesize > APP_CONFIG.program_size_limit
        return render json: { success: false, errors: { code_size: t('problems.edit.program_too_long') } }
      end
    end

    if problem.save
      affected_tags = problem.update_tags(tags)
      if affected_tags
        affected_tags.each { |id| clear_list_cache id }
        expire_fragment(controller: 'problems', action: 'list', action_suffix: 'filter_dialog')
      end
      problem.unzip_attachment_file(dir) if dir
      if need_clear_list_cache
        clear_list_cache
        problem.tags.each { |tag| clear_list_cache tag.id }
        clear_status_cache problem.id
        Problem.add_title problem.id, problem.title
      end
      clear_show_cache problem.id
      render json: { success: true, redirect_url: problems_show_url(problem.id) }
    else
      dir.rmtree if dir
      render json: { success: false, errors: problem.errors.to_hash }
    end
  end

  def upload_test_data
    @problem = Problem.find_by_id! params[:problem_id]
    unless params[:data_file].respond_to? :read
      return redirect_to problems_show_path(@problem.id), notice: t('problems.upload_test_data.empty')
    end
    @config = @problem.unzip_test_data_file params[:data_file]
    if @config[:errors]
      redirect_to problems_show_path(@problem.id), notice: @config[:errors]
    else
      clear_show_cache @problem.id
    end
  end

  def download_test_data
    unless @current_user && @current_user.role == 'admin' || params[:password] == APP_CONFIG.judge_client_password
      raise AppExceptions::NoPrivilegeError
    end
    problem = Problem.find_by_id! params[:problem_id]
    raise AppExceptions::InvalidOperation unless problem.test_data_timestamp
    send_file Rails.root.join('test_data', problem.id.to_s, 'data.zip'), filename: "#{problem.id}_data.zip"
  end

  def rejudge
    problem = Problem.find_by_id! params[:problem_id]
    raise AppExceptions::InvalidOperation unless problem.test_data_timestamp
    ids = problem.rejudge
    ids.each do |id|
      %w{normal self admin}.each do |name|
        expire_fragment controller: 'submissions', action: 'result', submission_id: id, action_suffix: name
      end
    end
    clear_status_cache problem.id
    clear_home_cache
    redirect_to :back, notice: t('problems.rejudge.success')
  end

  def search
    problem = Problem.find_by_id params[:problem_id]
    if problem
      redirect_to problems_show_url(problem.id)
    else
      redirect_to :back, notice: t('problems.search.not_exist', id: params[:problem_id])
    end
  end

  private
  def check_view_privilege
    problem = Problem.find_by_id! params[:problem_id]
    raise AppExceptions::NoPrivilegeError unless problem.has_view_privilege(@current_user)
  end

  def clear_home_cache
    now = Time.now
    expire_fragment controller: 'global', action: 'home', action_suffix: "top_users/#{now.beginning_of_day.to_i}"
    expire_fragment controller: 'global', action: 'home', action_suffix: "hot_problems/#{now.beginning_of_day.to_i}"
  end

  def clear_show_cache(problem_id)
    expire_fragment action: 'show', problem_id: problem_id, action_suffix: 'main'
    expire_fragment action: 'show', problem_id: problem_id, action_suffix: 'toolbar'
  end

  def clear_status_cache(problem_id)
    Rails.cache.delete "model/problem/total_page/#{problem_id}"
    total_page = (Problem.status_list_count(problem_id) - 1) / APP_CONFIG.page_size[:problem_status_list] + 1
    total_page = 1 if total_page == 0
    total_page = 5 if total_page > 5
    1.upto(total_page) do |page|
      expire_fragment action: 'status', problem_id: problem_id, page: page
    end
  end

  def clear_list_cache(tag_id = nil)
    Problem.clear_list_cache tag_id
    page_size = APP_CONFIG.page_size[:problems_list]
    %w{normal_user advanced_user admin}.each do |role|
      if tag_id
        total_page = (Problem.count_for_role(role, [tag_id]) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          expire_fragment action: 'list', page: page, action_suffix: "#{role}:#{tag_id}"
        end
      else
        total_page = (Problem.count_for_role(role, []) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          expire_fragment action: 'list', page: page, action_suffix: role
        end
      end
    end
  end
end
