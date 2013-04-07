class NotificationSweeper < ActionController::Caching::Sweeper
  observe Notification

  def after_create(notification)
    Notification.rebuild_unread_notifications notification.user_id
  end
end
