module SubmissionsHelper
  def result_cache_name
    if @current_user
      if @current_user.role == 'admin'
        'admin'
      elsif @current_user.id == @submission.user_id
        'self'
      else
        'normal'
      end
    else
      'normal'
    end
  end
end
