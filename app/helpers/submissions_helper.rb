module SubmissionsHelper
  def result_cache_name
    if @current_user
      if @current_user.id == @submission.user_id
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
