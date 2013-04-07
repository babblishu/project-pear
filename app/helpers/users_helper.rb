module UsersHelper
  def show_cache_name
    if @current_user
      if @current_user.id == @user.id
        'self'
      elsif @current_user.role == 'admin'
        'admin'
      else
        'normal'
      end
    else
      'normal'
    end
  end
end
