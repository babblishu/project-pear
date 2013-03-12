require 'cgi'

class ProblemMarkdownHTMLRender < Redcarpet::Render::HTML
  def block_code(code, language)
    code = CGI::escapeHTML code
    if APP_CONFIG.program_languages.keys.map(&:to_s).include? language
      "<pre class=\"prettyprint lang-#{language}\">\n#{code.gsub(/\t/, '    ')}</pre>"
    else
      "<pre>\n#{code.gsub(/\t/, '    ')}</pre>"
    end
  end
end

class ProblemsController < ApplicationController
  before_filter :require_admin, only: [ :create, :update, :edit, :upload_test_data, :rejudge ]

  def show
    @problem = Problem.includes(:tags, :content).find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless @problem

    begin
      check_view_privilege @current_user, @problem
    rescue AppExceptions::NoPrivilegeError
      return render 'problems/no_privilege'
    end
    @tags = @problem.tags.map(&:name).join(APP_CONFIG.tags_input_separate_char)
    @enable_latex = @problem.content.enable_latex
    @markdown = Redcarpet::Markdown.new ProblemMarkdownHTMLRender, no_intra_emphasis: true, fenced_code_blocks: true, lax_spacing: true
    @title = @problem.title
    @problem_active = true
  end

  def status
    @problem = Problem.find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless @problem

    check_view_privilege @current_user, @problem

    @page = (params[:page] || '1').to_i
    @page_size = APP_CONFIG.page_size[:problem_status_list]
    @total_page = calc_total_page Problem.status_list_count(@problem), @page_size
    validate_page_number @page, @total_page

    @status_list = Problem.status_list @problem, @page, @page_size
    @problem_active = true
    @title = t('problems.status.status_id', id: @problem.id)
  end

  def list
    tag_ids = []
    @tag_hash = {}
    Tag.all.each do |tag|
      if params["tag_#{tag.id}"]
        tag_ids << tag.id
        @tag_hash["tag_#{tag.id}"] = '1'
      end
    end

    @page = (params[:page] || '1').to_i
    page_size = APP_CONFIG.page_size[:problems_list]
    role = @current_user ? @current_user.role : 'normal_user'
    @total_page = calc_total_page Problem.count_for_role(role, tag_ids), page_size
    validate_page_number @page, @total_page

    if @current_user && @current_user.role == 'admin'
      @problem = Problem.new flash[:problem] || {}
      @problem_content = ProblemContent.new flash[:@problem_content] || {}
    end

    @problems = Problem.list_for_role role, tag_ids, @page, page_size
    @accepted_ids = @current_user.accepted_problem_ids if @current_user
    @attempted_ids = @current_user.attempted_problem_ids if @current_user
    @problem_active = true
    @title = t 'problems.list.problems_list'
  end

  def create
    problem = Problem.new params[:problem]
    problem.content = ProblemContent.new params[:problem_content]
    if problem.save
      render json: { success: true, redirect_url: problems_show_url(problem.id) }
    else
      render json: { success: false, errors: problem.errors.to_hash }
    end
  end

  def edit
    @problem = Problem.includes(:tags, :content).find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless @problem

    @tags = @problem.tags.map(&:name).join(APP_CONFIG.tags_input_separate_char)
    @tags = flash[:tags] || @tags

    @problem.attributes = flash[:problem] if flash[:problem]
    @problem.content.attributes = flash[:problem_content] if flash[:problem_content]

    @title = t 'problems.edit.edit_problem', id: @problem.id
    @problem_active = true
  end

  def update
    problem = Problem.includes(:content).find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless problem

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
      problem.update_tags tags
      problem.unzip_attachment_file(dir) if dir
      render json: { success: true, redirect_url: problems_show_url(problem.id) }
    else
      dir.rmtree if dir
      render json: { success: false, errors: problem.errors.to_hash }
    end
  end

  def upload_test_data
    @problem = Problem.find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless @problem
    unless params[:data_file].respond_to? :read
      return redirect_to problems_show_path(@problem.id), notice: t('problems.upload_test_data.empty')
    end
    @config = @problem.unzip_test_data_file params[:data_file]
    if @config[:errors]
      return redirect_to problems_show_path(@problem.id), notice: @config[:errors]
    end
    @problem_active = true
  end

  def download_test_data
    unless @current_user && @current_user.role == 'admin' || params[:password] == APP_CONFIG.judge_client_password
      raise AppExceptions::NoPrivilegeError
    end
    problem = Problem.find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless problem
    raise AppExceptions::NoTestDataError unless problem.test_data_timestamp
    send_file Rails.root.join('test_data', problem.id.to_s, 'data.zip'), filename: "#{problem.id}_data.zip"
  end

  def rejudge
    problem = Problem.find_by_id params[:problem_id]
    raise AppExceptions::InvalidProblemId unless problem
    raise AppExceptions::NoTestDataError unless problem.test_data_timestamp
    Submission.lock(true).update_all("status = 'waiting', time_used = null, memory_used = null, score = null, result = null",
                                     ['problem_id = :problem_id', problem_id: problem.id])
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
  def check_view_privilege(user, problem)
    role = user ? user.role : 'normal_user'
    if problem.status == 'hidden' && role != 'admin'
      raise AppExceptions::NoPrivilegeError
    end
    if problem.status == 'advanced' && role == 'normal_user'
      raise AppExceptions::NoPrivilegeError
    end
  end
end
