require 'my_html_render'

class DiscussController < ApplicationController
  before_filter :require_login, only: [ :topic, :primary_reply, :secondary_reply ]
  before_filter :require_admin, only: [ :admin ]
  before_filter :inspect_submit_interval, only: [ :topic, :primary_reply, :secondary_reply ]

  def show
    @topic = Topic.includes(:user, :problem).find_by_id params[:topic_id]
    raise AppExceptions::InvalidTopicId unless @topic
    check_view_privilege @current_user, @topic

    @page = (params[:page] || '1').to_i
    @page_size = APP_CONFIG.page_size[:topic_replies_list]
    @total_page = calc_total_page PrimaryReply.where('topic_id = :id', id: @topic.id).count + 1, @page_size
    validate_page_number @page, @total_page

    if @page == 1
      offset = 0
      limit = @page_size - 1
    else
      offset = @page_size * (@page - 1) - 1
      limit = @page_size
    end
    @replies = PrimaryReply.includes(:user, {:secondary_replies => :user}).
        where('topic_id = :id', id: @topic.id).order('created_at ASC, id ASC').offset(offset).limit(limit)

    @primary_reply = PrimaryReply.new

    @markdown = Redcarpet::Markdown.new(
        MyHTMLRender.new(escape_html: true, no_styles: true, safe_links_only: true),
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        autolink: true
    )
    @discuss_active = true
    @title = @topic.title
  end

  def list
    if params[:problem_id]
      @problem = Problem.find_by_id params[:problem_id]
      raise AppExceptions::InvalidProblemId unless @problem
      check_view_privilege @current_user, @problem
    end

    if @current_user
      @topic = Topic.new
      @topic.status = 'normal' if @current_user.role == 'admin'
      @topic.problem = @problem if @problem
    end

    @page = (params[:page] || '1').to_i
    page_size = APP_CONFIG.page_size[:discuss_list]
    role = @current_user ? @current_user.role : 'normal_user'
    if @problem
      @total_page = calc_total_page Topic.count_with_problem_for_role(role, @problem.id), page_size
    else
      @total_page = calc_total_page Topic.count_for_role(role), page_size
    end
    validate_page_number @page, @total_page

    if @problem
      @topics = Topic.list_with_problem_for_role role, @problem.id, @page, page_size
    else
      @topics = Topic.list_for_role role, @page, page_size
    end
    @discuss_active = true
    @title = @problem ? t('discuss.list.discuss_problem', id: @problem.id) : t('discuss.list.discuss')
  end

  def topic
    topic = nil
    if params[:operation] == 'create'
      topic = Topic.new user: @current_user
    else
      topic = Topic.includes(:user, :problem).find_by_id params[:topic_id]
      raise AppExceptions::InvalidTopicId unless topic
      check_view_privilege @current_user, topic
      check_update_privilege @current_user, topic
    end

    topic.assign_attributes params[:topic], without_protection: @current_user.role == 'admin'
    problem_id = (params[:topic][:problem_id] || '').strip
    if problem_id.empty?
      topic.problem_id = nil
    else
      unless problem_id =~ /\A\d{4}\Z/
        return render json: { success: false, errors: { problem_id: t('discuss.content_edit.invalid_problem_id') } }
      end
      problem = Problem.find_by_id problem_id
      unless problem
        return render json: { success: false, errors: { problem_id: t('discuss.content_edit.problem_not_exist') } }
      end
      begin
        check_view_privilege @current_user, problem
      rescue AppExceptions::NoPrivilegeError
        return render json: { success: false, errors: { problem_id: t('discuss.content_edit.no_privilege_to_problem') } }
      end
      topic.problem = problem
    end

    if params[:program].respond_to? :read
      topic.program = params[:program].read
      if topic.program.bytesize > APP_CONFIG.program_size_limit
        return render json: { success: false, errors: { code_size: t('discuss.content_edit.program_too_long') } }
      end
    end

    if topic.save
      if params[:operation] == 'update' && @current_user.id != topic.user.id
        create_notification 'edit_topic', topic, topic.user, topic
      end
      update_submit_times
      render json: { success: true, redirect_url: discuss_show_path(topic.id) }
    else
      render json: { success: false, errors: topic.errors.to_hash }
    end
  end

  def primary_reply
    if params[:operation] == 'create'
      topic = Topic.includes(:problem, :user).find_by_id params[:topic_id]
      raise AppExceptions::InvalidTopicId unless topic
      raise AppExceptions::NoPrivilegeError if topic.no_reply
      check_view_privilege @current_user, topic
      primary_reply = PrimaryReply.new user: @current_user, topic: topic
    else
      primary_reply = PrimaryReply.includes({:topic => :problem}, :user).find_by_id params[:primary_reply_id]
      raise AppExceptions::InvalidPrimaryReplyId unless primary_reply
      raise AppExceptions::NoPrivilegeError if primary_reply.hidden
      check_view_privilege @current_user, primary_reply.topic
      check_update_privilege @current_user, primary_reply
    end

    primary_reply.attributes = params[:primary_reply]

    if params[:program].respond_to? :read
      primary_reply.program = params[:program].read
      if primary_reply.program.bytesize > APP_CONFIG.program_size_limit
        return render json: { success: false, errors: { code_size: t('discuss.content_edit.program_too_long') } }
      end
    end

    if primary_reply.save
      if params[:operation] == 'create' && topic.user.id != @current_user.id
        create_notification 'create_primary_reply', topic, topic.user, primary_reply
      end
      if params[:operation] == 'update' && @current_user.id != primary_reply.user.id
        create_notification 'edit_reply', primary_reply.topic, primary_reply.user, primary_reply
      end
      update_submit_times
      render json: { success: true }
    else
      render json: { success: false, errors: primary_reply.errors.to_hash }
    end
  end

  def secondary_reply
    if params[:operation] == 'create'
      primary_reply = PrimaryReply.includes(:topic => :problem).find_by_id params[:primary_reply_id]
      raise AppExceptions::InvalidPrimaryReplyId unless primary_reply
      raise AppExceptions::NoPrivilegeError if primary_reply.topic.no_reply
      check_view_privilege @current_user, primary_reply.topic
      reply_to = User.find_by_handle params[:reply_to]
      raise AppExceptions::InvalidUserHandle unless reply_to
      secondary_reply = SecondaryReply.new user: @current_user, primary_reply: primary_reply
    else
      secondary_reply = SecondaryReply.includes({:primary_reply => {:topic => :problem}}, :user).
          find_by_id params[:secondary_reply_id]
      raise AppExceptions::InvalidSecondaryReplyId unless secondary_reply
      raise AppExceptions::NoPrivilegeError if secondary_reply.hidden
      check_view_privilege @current_user, secondary_reply.primary_reply.topic
      check_update_privilege @current_user, secondary_reply
    end

    secondary_reply.content = params[:content]
    if secondary_reply.save
      if params[:operation] == 'create' && reply_to.id != @current_user.id
        create_notification 'create_secondary_reply', primary_reply.topic, reply_to, secondary_reply
      end
      if params[:operation] == 'update' && @current_user.id != secondary_reply.user.id
        create_notification 'edit_reply', secondary_reply.primary_reply.topic, secondary_reply.user, secondary_reply
      end
      update_submit_times
      render json: { success: true }
    else
      render json: { success: false, error: secondary_reply.errors[:content][0] }
    end
  end

  def locate
    if params[:type] == 'primary_reply'
      primary_reply = PrimaryReply.includes(:topic).find_by_id params[:id]
      raise AppExceptions::InvalidPrimaryReplyId unless primary_reply
      topic = primary_reply.topic
      suffix = "#primary_reply_#{primary_reply.id}"
    else
      secondary_reply = SecondaryReply.includes(:primary_reply => :topic).find_by_id params[:id]
      raise AppExceptions::InvalidSecondaryReplyId unless secondary_reply
      primary_reply = secondary_reply.primary_reply
      topic = primary_reply.topic
      suffix = "#secondary_reply_#{secondary_reply.id}"
    end

    page_size = APP_CONFIG.page_size[:topic_replies_list]
    count = PrimaryReply.where('topic_id = :topic_id AND (created_at < :time OR created_at = :time AND id <= :id)',
                               topic_id: topic.id, time: primary_reply.created_at, id: primary_reply.id).count
    if count < page_size
      redirect_to discuss_show_path(primary_reply.topic.id) + suffix
    else
      page = count / page_size + 1
      redirect_to discuss_show_path(primary_reply.topic.id, page) + suffix
    end
  end

  def download_code
    if params[:type] == 'topic'
      topic = Topic.find_by_id params[:id]
      raise AppExceptions::InvalidTopicId unless topic
      raise AppExceptions::InvalidOperation unless topic.program && !topic.program.empty?
      check_view_privilege @current_user, topic
      send_data topic.program, filename: 'Main.' + topic.language
    else
      primary_reply = PrimaryReply.find_by_id params[:id]
      raise AppExceptions::InvalidPrimaryReplyId unless primary_reply
      raise AppExceptions::InvalidOperation unless primary_reply.program && !primary_reply.program.empty?
      raise AppExceptions::NoPrivilegeError if primary_reply.hidden
      check_view_privilege @current_user, primary_reply.topic
      send_data primary_reply.program, filename: 'Main.' + primary_reply.language
    end
  end

  def admin
    if params[:primary_reply_id]
      modal = PrimaryReply.includes(:topic).find_by_id params[:primary_reply_id]
      topic = modal.topic
      raise AppExceptions::InvalidPrimaryReplyId unless modal
    end

    if params[:secondary_reply_id]
      modal = SecondaryReply.includes(:primary_reply => :topic).find_by_id params[:secondary_reply_id]
      topic = modal.primary_reply.topic
      raise AppExceptions::InvalidSecondaryReplyId unless modal
    end

    if params[:operation] == 'show'
      modal.update_attribute :hidden, false
      create_notification 'show_reply', topic, modal.user, modal
    end

    if params[:operation] == 'hide'
      modal.update_attribute :hidden, true
      create_notification 'hide_reply', topic, modal.user, modal
    end

    redirect_to :back, notice: t('discuss.content_edit.success')
  end

  private
  def check_view_privilege(user, modal)
    role = user ? user.role : 'normal_user'
    if modal.status == 'hidden' && role != 'admin'
      raise AppExceptions::NoPrivilegeError
    end
    if modal.status == 'advanced' && role == 'normal_user'
      raise AppExceptions::NoPrivilegeError
    end
    if modal.respond_to?(:problem) && modal.problem
      if modal.problem.status == 'advanced' && role == 'normal_user'
        raise AppExceptions::NoPrivilegeError
      end
    end
  end

  def check_update_privilege(user, modal)
    unless user.role == 'admin' || user.id == modal.user.id
      raise AppExceptions::NoPrivilegeError
    end
  end

  def create_notification(selector, topic, user, modal)
    hash = {
        title: topic.title,
        user_link: users_show_path(@current_user.handle),
        handle: @current_user.handle
    }
    if modal.is_a? Topic
      hash[:topic_link] = discuss_show_path(modal.id)
    elsif modal.is_a? PrimaryReply
      hash[:reply_link] = discuss_locate_path('primary_reply', modal.id)
    elsif modal.is_a? SecondaryReply
      hash[:reply_link] = discuss_locate_path('secondary_reply', modal.id)
    end
    Notification.create(
        user: user,
        content: t('discuss.notification.' + selector, hash)
    )
  end
end
