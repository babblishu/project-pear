class MessagesController < ApplicationController
  before_filter :require_login, only: [ :notifications, :list, :show, :create ]
  before_filter :inspect_submit_interval, only: [ :create ]

  def notifications
    page_size = APP_CONFIG.page_size[:notifications]
    if params[:ajax]
      notifications = Notification.list(@current_user.id, params[:excepted_ids].map(&:to_i), page_size)
      response = {}
      if notifications.size <= page_size
        response[:is_last_page] = true
      else
        notifications.pop
      end
      Notification.update_all 'read = TRUE', ['id IN (?)', notifications.map(&:id) ]
      response[:data] = notifications.map do |notification|
        {
            id: notification.id,
            content: view_context.simple_format(notification.content),
            created_at: view_context.format_datetime(notification.created_at),
            read: notification.read
        }
      end
      render json: response
    else
      @notifications = Notification.list(@current_user.id, [], page_size)
      if @notifications.size <= page_size
        @is_last_page = true
      else
        @notifications.pop
      end
      Notification.update_all 'read = TRUE', ['id IN (?)', @notifications.map(&:id) ]
      @title = t 'messages.notifications.title'
    end
  end

  def list
    @page = (params[:page] || '1').to_i
    page_size = APP_CONFIG.page_size[:messages_list]
    @total_page = calc_total_page Message.list_count(@current_user.id), page_size
    validate_page_number @page, @total_page
    @messages = Message.list(@current_user.id, @page, page_size)
    @title = t 'messages.list.title'
  end

  def show
    @user = User.fetch_by_uniq_key params[:handle], :handle
    raise AppExceptions::InvalidUserHandle unless @user
    raise AppExceptions::InvalidOperation if @user.id == @current_user.id
    page_size = APP_CONFIG.page_size[:messages_show_list]
    if params[:ajax]
      messages = Message.detail_list(@user.id, @current_user.id, params[:excepted_ids].map(&:to_i), page_size)
      response = {}
      if messages.size <= page_size
        response[:is_last_page] = true
      else
        messages.pop
      end
      response[:data] = messages.map do |message|
        {
            id: message.id,
            content: view_context.simple_format(message.content),
            created_at: view_context.format_datetime(message.created_at),
            read: message.read,
            from: message.from.id == @user.id
        }
      end
      Message.update_all 'read = TRUE', ['id IN (?) AND user_to = ?', messages.map(&:id), @current_user.id ]
      render json: response
    else
      @messages = Message.detail_list(@user.id, @current_user.id, [], page_size)
      raise AppExceptions::InvalidOperation if @messages.empty?
      if @messages.size <= page_size
        @is_last_page = true
      else
        @messages.pop
      end
      Message.update_all 'read = TRUE', ['id IN (?) AND user_to = ?', @messages.map(&:id), @current_user.id ]
      @title = t 'messages.show.title', handle: @user.handle
    end
  end

  def create
    user = User.fetch_by_uniq_key params[:handle], :handle
    raise AppExceptions::InvalidUserHandle unless user
    raise AppExceptions::InvalidOperation if user.id == @current_user.id
    message = Message.new content: params[:content], from: @current_user, to: user
    if message.save
      update_submit_times
      render json: { success: true, notice: t('messages.create.success') }
    else
      render json: { success: false, error: message.errors[:content][0] }
    end
  end
end
