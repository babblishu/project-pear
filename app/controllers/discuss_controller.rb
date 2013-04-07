class DiscussController < ApplicationController
  before_filter :require_login, only: [ :topic, :primary_reply, :secondary_reply ]
  before_filter :require_admin, only: [ :admin ]
  before_filter :inspect_submit_interval, only: [ :topic, :primary_reply, :secondary_reply ]
  cache_sweeper :notification_sweeper

  def show
    @topic = Topic.find_by_id! params[:topic_id]
    check_view_privilege @current_user, @topic

    @page = (params[:page] || '1').to_i
    @page_size = APP_CONFIG.page_size[:topic_replies_list]
    @total_page = Rails.cache.fetch("model/topic/total_page/#{@topic.id}") do
      calc_total_page PrimaryReply.where('topic_id = :id', id: @topic.id).count + 1, @page_size
    end
    validate_page_number @page, @total_page
  end

  def list
    if params[:problem_id]
      @problem = Problem.find_by_id! params[:problem_id]
      check_view_privilege @current_user, @problem
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
  end

  def topic
    if params[:operation] == 'create'
      topic = Topic.new user: @current_user
    else
      topic = Topic.find_by_id! params[:topic_id]
      check_view_privilege @current_user, topic
      check_update_privilege @current_user, topic
      original_problem_id = topic.problem_id
      need_clear_list_cache = false
      need_clear_list_cache ||= topic.title != params[:topic][:title]
      need_clear_list_cache ||= topic.status != params[:topic][:status]
      need_clear_list_cache ||= topic.top != (params[:topic][:top] == '1')
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
      if params[:operation] == 'update'
        if original_problem_id != topic.problem_id
          clear_list_cache
          clear_list_cache(topic.problem_id) if topic.problem_id
          clear_list_cache(original_problem_id) if original_problem_id
        elsif need_clear_list_cache
          clear_list_cache
          clear_list_cache(topic.problem_id) if topic.problem_id
        end
        clear_show_cache topic.id, 1
      else
        clear_list_cache
        clear_list_cache(topic.problem_id) if topic.problem_id
      end
      update_submit_times
      render json: { success: true, redirect_url: discuss_show_path(topic.id) }
    else
      render json: { success: false, errors: topic.errors.to_hash }
    end
  end

  def primary_reply
    if params[:operation] == 'create'
      topic = Topic.find_by_id! params[:topic_id]
      raise AppExceptions::NoPrivilegeError if topic.no_reply
      check_view_privilege @current_user, topic
      primary_reply = PrimaryReply.new user: @current_user, topic: topic
    else
      primary_reply = PrimaryReply.find_by_id! params[:primary_reply_id]
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
      if params[:operation] == 'create'
        clear_list_cache
        problem_id = topic.problem_id
        clear_list_cache(problem_id) if problem_id
        page_no = primary_reply.page_no
        clear_show_cache(topic.id, page_no)
        clear_show_cache(topic.id, page_no - 1) if page_no > 1
        Rails.cache.delete "model/topic/total_page/#{topic.id}"
      else
        clear_show_cache primary_reply.topic_id, primary_reply.page_no
      end
      update_submit_times
      render json: { success: true }
    else
      render json: { success: false, errors: primary_reply.errors.to_hash }
    end
  end

  def secondary_reply
    if params[:operation] == 'create'
      primary_reply = PrimaryReply.find_by_id! params[:primary_reply_id]
      raise AppExceptions::NoPrivilegeError if primary_reply.topic.no_reply
      check_view_privilege @current_user, primary_reply.topic
      reply_to = User.fetch_by_uniq_key! params[:reply_to], :handle
      secondary_reply = SecondaryReply.new user: @current_user, primary_reply: primary_reply
    else
      secondary_reply = SecondaryReply.find_by_id! params[:secondary_reply_id]
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
      if params[:operation] == 'create'
        clear_list_cache
        problem_id = primary_reply.topic.problem_id
        clear_list_cache(problem_id) if problem_id
      end
      clear_show_cache secondary_reply.primary_reply.topic_id, secondary_reply.primary_reply.page_no
      update_submit_times
      render json: { success: true }
    else
      render json: { success: false, error: secondary_reply.errors[:content][0] }
    end
  end

  def locate
    if params[:type] == 'primary_reply'
      primary_reply = PrimaryReply.find_by_id! params[:id]
      suffix = "#primary_reply_#{primary_reply.id}"
    else
      secondary_reply = SecondaryReply.find_by_id! params[:id]
      primary_reply = secondary_reply.primary_reply
      suffix = "#secondary_reply_#{secondary_reply.id}"
    end
    redirect_to discuss_show_path(primary_reply.topic_id, primary_reply.page_no) + suffix
  end

  def download_code
    if params[:type] == 'topic'
      topic = Topic.find_by_id! params[:id]
      raise AppExceptions::InvalidOperation unless topic.program && !topic.program.empty?
      check_view_privilege @current_user, topic
      send_data topic.program, filename: 'Main.' + topic.language
    else
      primary_reply = PrimaryReply.find_by_id! params[:id]
      raise AppExceptions::InvalidOperation unless primary_reply.program && !primary_reply.program.empty?
      raise AppExceptions::NoPrivilegeError if primary_reply.hidden
      check_view_privilege @current_user, primary_reply.topic
      send_data primary_reply.program, filename: 'Main.' + primary_reply.language
    end
  end

  def admin
    if params[:primary_reply_id]
      modal = PrimaryReply.find_by_id! params[:primary_reply_id]
      topic = modal.topic
      clear_show_cache topic.id, modal.page_no
    end

    if params[:secondary_reply_id]
      modal = SecondaryReply.find_by_id! params[:secondary_reply_id]
      topic = modal.primary_reply.topic
      clear_show_cache topic.id, modal.primary_reply.page_no
    end

    if params[:operation] == 'show'
      modal.update_attribute :hidden, false
      create_notification('show_reply', topic, modal.user, modal) unless @current_user.id == modal.user.id
    end

    if params[:operation] == 'hide'
      modal.update_attribute :hidden, true
      create_notification('hide_reply', topic, modal.user, modal) unless @current_user.id == modal.user.id
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

  def clear_list_cache(problem_id = nil)
    unless problem_id
      %w{normal_user advanced_user admin}.each do |role|
        expire_fragment controller: 'global', action: 'home', action_suffix: "discuss/#{role}"
      end
    end

    Topic.clear_list_cache problem_id
    page_size = APP_CONFIG.page_size[:discuss_list]
    %w{guest normal_user advanced_user admin}.each do |role|
      if problem_id
        total_page = (Topic.count_with_problem_for_role(role, problem_id) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          expire_fragment action: 'list', page: page, action_suffix: "#{role}:#{problem_id}"
        end
      else
        total_page = (Topic.count_for_role(role) - 1) / page_size + 1
        total_page = 1 if total_page == 0
        1.upto(total_page) do |page|
          expire_fragment action: 'list', page: page, action_suffix: role
        end
      end
    end
  end

  def clear_show_cache(topic_id, page_no)
    %w{normal guest admin}.each do |role|
      expire_fragment action: 'show', topic_id: topic_id, page: page_no, action_suffix: role
    end
  end
end
