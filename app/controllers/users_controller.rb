class UsersController < ApplicationController
  before_filter :require_login, only: [ :logout, :edit, :edit_password, :update, :update_password, :compare ]
  before_filter :require_admin, only: [ :admin, :add_advanced_users, :admin_advanced_users ]
  before_filter :inspect_submit_interval, only: [ :update, :update_password ]
  cache_sweeper :notification_sweeper

  def login
    user = User.fetch_by_uniq_key params[:handle], :handle
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
    redirect_to root_url
  end

  def register
    redirect_to root_url if @current_user
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
        User.add_user user
      else
        response = { success: false, errors: user.errors.to_hash }
      end
    else
      response = { success: false, errors: { captcha: t('users.create.wrong_captcha') } }
    end
    render json: response
  end

  def show
    @user = User.fetch_by_uniq_key! params[:handle], :handle
    if @user.blocked
      raise AppExceptions::NoPrivilegeError unless @current_user && @current_user.role == 'admin'
    end
  end

  def compare
    @user = User.fetch_by_uniq_key! params[:handle], :handle
    raise AppExceptions::NoPrivilegeError if @user.blocked
    @you_accepted = @current_user.accepted_problem_ids
    @he_accepted = @user.accepted_problem_ids
    @both = @you_accepted.select { |x| @he_accepted.include? x }
    @you_accepted.select! { |x| !@both.include? x }
    @he_accepted.select! { |x| !@both.include? x }
  end

  def edit
    @user = User.fetch_by_uniq_key! params[:handle], :handle
    raise AppExceptions::NoPrivilegeError if @current_user.id != @user.id && @current_user.role != 'admin'
  end

  def update
    user = User.fetch_by_uniq_key! params[:handle], :handle
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
      clear_show_cache user
    else
      response = { success: false, errors: user.errors.to_hash }
    end
    render json: response
  end

  def edit_password
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

    now = Time.now
    @total_page = calc_total_page User.rank_list_count(now, @span), @page_size
    validate_page_number @page, @total_page
    @rank_list = User.rank_list now, @span, @page, @page_size
  end

  def admin
    user = User.fetch_by_uniq_key! params[:handle], :handle
    if @current_user.authenticate params[:password]
      case params[:operation]
        when 'upto_admin'
          raise AppExceptions::InvalidOperation if user.blocked
          User.remove_handle_index(:normal_user_index, user.handle) if user.role == 'normal_user'
          user.update_attribute :role, 'admin'
        when 'block_user'
          raise AppExceptions::InvalidOperation if user.blocked
          User.block_user(user)
          clear_home_cache
        when 'unblock_user'
          raise AppExceptions::InvalidOperation unless user.blocked
          User.unblock_user(user)
          clear_home_cache
        else
      end
      response = { success: true, notice: t('users.admin.success') }
      clear_show_cache user, 'admin'
    else
      response = { success: false, errors: { password: t('users.admin.wrong_password') } }
    end
    render json: response
  end

  def search
    if params[:ajax]
      if params[:add_advanced_users]
        user = User.fetch_by_uniq_key params[:handle], :handle
        return render json: { success: false, notice: t('users.search.not_exist', handle: params[:handle]) } unless user
        return render json: { success: false, notice: t('users.search.not_normal_user', handle: user.handle)} unless user.role == 'normal_user'
        return render json: { success: false, notice: t('users.search.blocked_user', handle: user.handle)} if user.blocked
        render json: {
            success: true,
            handle: user.handle,
            real_name: user.information.real_name,
            school: user.information.school,
            cancel_confirm: t('users.search.cancel_confirm', handle: user.handle)
        }
      else
        if params[:add_advanced_users_auto_complete]
          key = APP_CONFIG.redis_namespace[:normal_user_index] + params[:handle].downcase
          users = $redis.srandmember(key, 9)
        else
          key = APP_CONFIG.redis_namespace[:user_index] + params[:handle].downcase
          users = $redis.srandmember(key, 9)
        end
        users = [] unless users.size < 9
        render json: users
      end
    else
      user = User.fetch_by_uniq_key params[:handle], :handle
      if user
        redirect_to users_show_url(user.handle)
      else
        redirect_to :back, notice: t('users.search.not_exist', handle: params[:handle])
      end
    end
  end

  def add_advanced_users
  end

  def admin_advanced_users
    if params[:operation] == 'add'
      handles = params[:handles]
      unless User.where('blocked AND handle IN (:handles)', handles: handles).empty?
        return render json: { success: false, notice: t('users.admin_advanced_users.have_blocked_users') }
      end
      unless User.where("role <> 'normal_user' AND handle IN (:handles)", handles: handles).empty?
        return render json: { success: false, notice: t('users.admin_advanced_users.have_not_normal_users') }
      end
      unless User.where('handle IN (:handles)', handles: handles).size == handles.size
        return render json: { success: false, notice: t('users.admin_advanced_users.have_invalid_handle') }
      end
      handles.each do |handle|
        user = User.fetch_by_uniq_key handle, :handle
        user.update_attribute :role, 'advanced_user'
        Notification.create(
            user: user,
            content: t(
                'users.notification.upto_advanced_user',
                admin_link: users_show_path(@current_user.handle),
                handle: @current_user.handle
            )
        )
        User.remove_handle_index :normal_user_index, user.handle
      end
      render json: { success: true, redirect_url: root_url, notice: t('users.admin_advanced_users.success') }
    end
  end

  private
  def clear_show_cache(user, name = nil)
    %w{normal self admin}.each do |tmp|
      next if name && tmp != name
      expire_fragment action: 'show', handle: user.handle, action_suffix: tmp
    end
  end

  def clear_home_cache
    now = Time.now
    expire_fragment controller: 'global', action: 'home', action_suffix: "top_users/#{now.beginning_of_day.to_i}"
    expire_fragment controller: 'global', action: 'home', action_suffix: "hot_problems/#{now.beginning_of_day.to_i}"
  end
end
