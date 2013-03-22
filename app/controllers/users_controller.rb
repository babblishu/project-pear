class UsersController < ApplicationController
  before_filter :require_login, only: [ :logout, :edit, :edit_password, :update, :update_password, :compare ]
  before_filter :require_admin, only: [ :admin ]
  before_filter :inspect_submit_interval, only: [ :update, :update_password ]

  def login
    user = User.find_by_handle params[:handle]
    if user
      if user.authenticate(params[:password])
        if user.blocked
          return render json: { success: false, error: t('users.login.blocked') }
        end
        session[:user_handle] = user.handle
        if params[:remember_login]
          cookies.signed[:user_handle] = { value: user.handle, expires: 3.months.from_now }
        end
        render json: { success: true }
      else
        render json: { success: false, error: t('users.login.wrong_password') }
      end
    else
      render json: { success: false, error: t('users.login.invalid_handle') }
    end
  end

  def logout
    session[:user_handle] = nil
    cookies.delete :user_handle
    redirect_to :back
  end

  def register
    if @current_user
      redirect_to root_url
    end
    @user = User.new
    @user_information = UserInformation.new
    @title = t 'users.register.register'
  end

  def create
    params[:user].delete :avatar unless params[:user][:avatar].respond_to? :read
    user = User.new params[:user]
    user.information = UserInformation.new params[:user_information]
    user.last_submit = Time.now
    if valid_captcha? params[:captcha]
      if user.save
        response = { success: true, notice: t('users.create.success'), redirect_url: root_url }
        session[:user_handle] = user.handle
      else
        response = { success: false, errors: user.errors.to_hash }
      end
    else
      response = { success: false, errors: { captcha: t('users.create.wrong_captcha') } }
    end
    render json: response
  end

  def show
    @user = User.includes(:information).find_by_handle params[:user_handle]
    raise AppExceptions::InvalidUserHandle unless @user
    @title = @user.handle
  end

  def compare
    @user = User.includes(:information).find_by_handle params[:user_handle]
    raise AppExceptions::InvalidUserHandle unless @user
    @you_accepted = @current_user.accepted_problem_ids
    @he_accepted = @user.accepted_problem_ids
    @both = @you_accepted.select { |x| @he_accepted.include? x }
    @you_accepted.select! { |x| !@both.include? x }
    @he_accepted.select! { |x| !@both.include? x }
    @title = t('users.compare.compare_with', handle: @user.handle)
  end

  def edit
    @user = User.includes(:information).find_by_handle params[:user_handle]
    raise AppExceptions::InvalidUserHandle unless @user
    raise AppExceptions::NoPrivilegeError if @current_user.id != @user.id && @current_user.role != 'admin'
    @title = t 'users.edit.edit_profile'
  end

  def update
    user = User.includes(:information).find_by_handle params[:user_handle]
    raise AppExceptions::InvalidUserHandle unless user
    raise AppExceptions::NoPrivilegeError if @current_user.id != user.id && @current_user.role != 'admin'
    if params[:user]
      params[:user].delete :avatar unless params[:user][:avatar].respond_to? :read
    end
    user.attributes = params[:user]
    user.information.attributes = params[:user_information]
    if user.save
      update_submit_times
      if user.id != @current_user.id
        Notification.create(
            user: user,
            content: t(
                'users.notification.edit_profile',
                admin_link: users_show_path(@current_user.handle),
                handle: @current_user.handle,
                user_link: users_show_path(user.handle)
            )
        )
      end
      response = { success: true, notice: t('users.update.success'), redirect_url: users_show_url(user.handle) }
    else
      response = { success: false, errors: user.errors.to_hash }
    end
    render json: response
  end

  def edit_password
    @title = t 'users.edit_password.edit_password'
  end

  def update_password
    if @current_user.authenticate params[:old_password]
      if params[:new_password] && !params[:new_password].empty?
        if @current_user.update_attributes(password: params[:new_password],
                                           password_confirmation: params[:new_password_confirmation])
          session[:user_handle] = nil
          cookies.delete :user_handle
          response = { success: true, redirect_url: root_url, notice: t('users.update_password.success') }
        else
          response = { success: false, errors: @current_user.errors.to_hash }
        end
      else
        response = { success: false, errors: { password_digest: t('users.update_password.blank_new_password') } }
      end
    else
      response = { success: false, errors: { old_password: t('users.update_password.wrong_password') } }
    end
    render json: response
  end

  def list
    @page = (params[:page] || '1').to_i
    @page_size = APP_CONFIG.page_size[:users_rank_list]
    @span = params[:span]

    time_now = Time.now
    case @span
      when 'year'
        time = time_now.beginning_of_year
      when 'month'
        time = time_now.beginning_of_month
      when 'week'
        time = time_now.beginning_of_week
      when 'day'
        time = time_now.beginning_of_day
      else
        time = Time.local(2000)
    end

    @rank_list = User.rank_list time, @page, @page_size
    if @rank_list.size <= @page_size
      @is_last_page = true
    else
      @rank_list.pop
    end
    @rank_active = true
    @title = t 'users.list.rank'
  end

  def admin
    user = User.find_by_handle params[:user_handle]
    raise AppExceptions::InvalidUserHandle unless user
    if @current_user.authenticate params[:password]
      case params[:operation]
        when 'upto_advanced_user'
          user.update_attribute :role, 'advanced_user'
          Notification.create(
              user: user,
              content: t(
                  'users.notification.upto_advanced_user',
                  admin_link: users_show_path(@current_user.handle),
                  handle: @current_user.handle
              )
          )
        when 'upto_admin'
          user.update_attribute :role, 'admin'
        when 'block_user'
          user.update_attribute :blocked, true
        when 'unblock_user'
          user.update_attribute :blocked, false
        else
      end
      response = { success: true, notice: t('users.admin.success') }
    else
      response = { success: false, errors: { password: t('users.admin.wrong_password') } }
    end
    render json: response
  end

  def search
    if params[:ajax]
      pattern = '%' + params[:handle].to_s + '%'
      users = User.where('handle ILIKE :pattern', pattern: pattern).limit(9).map(&:handle)
      users = [] unless users.size < 9
      render json: users
    else
      user = User.find_by_handle params[:handle]
      if user
        redirect_to users_show_url(user.handle)
      else
        redirect_to :back, notice: t('users.search.not_exist', handle: params[:handle])
      end
    end
  end
end
