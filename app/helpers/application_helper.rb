module ApplicationHelper
  def page_title(title)
    if title
      title + ' - ' + APP_CONFIG.oj_name
    else
      APP_CONFIG.oj_name
    end
  end

  def user_link(user_handle)
    link_to user_handle, users_show_path(user_handle), target: '_blank'
  end

  def user_avatar_link(user, style)
    link_to image_tag(user.avatar.url(style)), users_show_path(user.handle), target: '_blank'
  end

  def problem_link(problem_id)
    link_to problem_id.to_s, problems_show_path(problem_id.to_s), target: '_blank'
  end

  def submission_link(submission_id)
    link_to submission_id.to_s, submissions_result_path(submission_id.to_s), target: '_blank'
  end

  def user_accepted_submissions_link(content, user_handle)
    link_to content.to_s, submissions_list_path(handle: user_handle, min_score: '100', choose_all: '1'), target: '_blank'
  end

  def user_attempted_submissions_link(content, user_handle)
    link_to content.to_s, submissions_list_path(handle: user_handle, choose_all: '1'), target: '_blank'
  end

  def problem_accepted_submissions_link(content, problem_id)
    link_to content.to_s, submissions_list_path(problem_id: problem_id, min_score: '100', choose_all: '1'), target: '_blank'
  end

  def problem_attempted_submissions_link(content, problem_id)
    link_to content.to_s, submissions_list_path(problem_id: problem_id, choose_all: '1'), target: '_blank'
  end

  def ratio_str(a, b)
    if b == 0
      '0%'
    else
      (a * 100 / b).to_s + '%'
    end
  end

  def format_datetime(time)
    time.getlocal.strftime('%Y-%m-%d %T')
  end

  def format_date(time)
    time.getlocal.strftime('%Y-%m-%d')
  end

  def format_time_used(time_used)
    time_used ? sprintf('%.3f s', time_used / 1000.0) : t('global.unknown')
  end

  def format_memory_used(memory_used)
    memory_used ? sprintf('%.2f MB', memory_used / 1024.0) : t('global.unknown')
  end

  def format_language(language)
    APP_CONFIG.program_languages[language.to_sym]
  end

  def format_platform(platform)
    APP_CONFIG.judge_platforms[platform.to_sym]
  end

  def format_code_size(code_size)
    sprintf('%.2f KB', code_size / 1024.0)
  end

  def get_error_message(errors, *fields)
    return '' unless errors
    fields.each do |x|
      if errors[x]
        return errors[x] if errors[x].is_a? String
        return errors[x][0] if errors[x].is_a? Array
      end
    end
    ''
  end

  def admin?
    @current_user && @current_user.role == 'admin'
  end

  def owner?(modal)
    return false unless @current_user
    if modal.respond_to? :user
      return modal.user.id == @current_user.id if modal.user.respond_to? :id
    end
    if modal.respond_to? :user_id
      return modal.user_id == @current_user.id
    end
    if modal.respond_to? :user_handle
      return modal.user_handle == @current_user.handle
    end
    if modal.respond_to? :handle
      return modal.handle == @current_user.handle
    end
    false
  end
end
