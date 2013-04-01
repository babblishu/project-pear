require 'exceptions'

class ApplicationController < ActionController::Base
  # reset captcha code after each request for security
  after_filter :reset_last_captcha_code!

  protect_from_forgery

  before_filter :inspect_login_cookie
  before_filter :inspect_current_user
  before_filter :inspect_blocked_user
  before_filter :inspect_need_captcha
  before_filter :inspect_notification
  before_filter :inspect_message

  rescue_from AppExceptions::InvalidPageNumber, with: :render_404_page
  rescue_from ActiveRecord::RecordNotFound, with: :render_404_page
  rescue_from AppExceptions::InvalidUserHandle, with: :render_404_page
  rescue_from AppExceptions::InvalidProblemId, with: :render_404_page
  rescue_from AppExceptions::InvalidSubmissionId, with: :render_404_page
  rescue_from AppExceptions::InvalidTopicId, with: :render_404_page
  rescue_from AppExceptions::InvalidPrimaryReplyId, with: :render_404_page
  rescue_from AppExceptions::InvalidSecondaryReplyId, with: :render_404_page
  rescue_from AppExceptions::NoTestDataError, with: :render_invalid_operation_page
  rescue_from AppExceptions::InvalidOperation, with: :render_invalid_operation_page

  rescue_from AppExceptions::RequireLoginError, with: :render_require_login_page
  rescue_from AppExceptions::NoPrivilegeError, with: :render_no_privilege_page

  def render_404_page
    @some_wrong = true
    @title = t('global.something_wrong')
    render 'errors/404', layout: 'application', status: 404
  end

  private
  def render_require_login_page
    redirect_to root_url, notice: t('global.require_login')
  end

  def render_no_privilege_page
    redirect_to root_url, notice: t('global.no_privilege')
  end

  def render_invalid_operation
    redirect_to root_url, notice: t('global.invalid_operation')
  end

  protected
  def inspect_login_cookie
    unless session[:user_handle]
      session[:user_handle] = cookies.signed[:user_handle]
    end
  end

  def inspect_current_user
    if session[:user_handle]
      @current_user = User.fetch_by_uniq_key session[:user_handle], :handle
      if @current_user && request.remote_ip != @current_user.remote_ip
        @current_user.update_attribute :remote_ip, request.remote_ip
      end
    end
  end

  def inspect_blocked_user
    if @current_user && @current_user.blocked
      @current_user = nil
      session[:user_handle] = nil
      cookies.delete :user_handle
    end
  end

  def inspect_notification
    if @current_user
      @notifications_count = Notification.where('user_id = :user_id AND NOT read', user_id: @current_user.id).count
    end
  end

  def inspect_message
    if @current_user
      @messages_count = Message.where('user_to = :user_id AND NOT read', user_id: @current_user.id).count
    end
  end

  def inspect_need_captcha
    return if action_name == 'captcha_verify' || action_name == 'captcha_verify_submit' || action_name == 'logout'
    if @current_user && @current_user.need_captcha
      redirect_to captcha_verify_url
    end
  end

  def inspect_submit_interval
    if @current_user && @current_user.role != 'admin'
      if Time.now - @current_user.last_submit < APP_CONFIG.minimum_submit_interval
        render json: { success: false, notice: t('global.submit_too_fast', t: APP_CONFIG.minimum_submit_interval) }
      end
    end
  end

  def require_login
    raise AppExceptions::RequireLoginError unless @current_user
  end

  def require_admin
    raise AppExceptions::NoPrivilegeError unless @current_user && @current_user.role == 'admin'
  end

  def require_judge_client
    raise AppExceptions::NoPrivilegeError unless params[:password] == APP_CONFIG.judge_client_password
  end

  def check_submit_interval
    Time.now - @current_user.last_submit >= APP_CONFIG.minimum_submit_interval
  end

  def calc_total_page(count, page_size)
    [count - 1, 0].max / page_size + 1
  end

  def validate_page_number(page, total_page)
    raise AppExceptions::InvalidPageNumber unless 1 <= page && page <= total_page
  end

  def update_submit_times
    return if @current_user.role == 'admin'
    User.transaction do
      @current_user.lock!
      times = @current_user.submit_times
      need_captcha = @current_user.need_captcha
      if Time.now - @current_user.last_submit > APP_CONFIG.reset_submit_counter_interval
        times = 0
      end
      times += 1
      if times == APP_CONFIG.need_captcha_bound
        need_captcha = true
        times = 0
      end
      @current_user.update_attributes({
        submit_times: times,
        need_captcha: need_captcha,
        last_submit: Time.now
      }, without_protection: true)
    end
  end
end
