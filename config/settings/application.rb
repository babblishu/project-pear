SimpleConfig.for :application do
  set :oj_name, 'My OJ'
  set :version_str, 'alpha2'
  set :judge_client_password, 'password'
  
  set :page_size, {
      discuss_list: 20,
      topic_replies_list: 10,
      notifications: 5,
      messages_list: 10,
      messages_show_list: 8,
      problems_list: 50,
      problem_status_list: 15,
      submissions_list: 15,
      users_rank_list: 30
  }
  set :program_languages, {
      c: 'C',
      cpp: 'C++',
      pas: 'Pascal',
      java: 'Java',
      bas: 'BASIC'
  }
  set :judge_platforms, {
      windows: 'Windows',
      linux: 'Linux'
  }
  set :program_size_limit, 50.kilobytes
  set :tags_input_separate_char, ' '
  set :topic_length_limit, 2000
  set :primary_reply_length_limit, 2000
  set :secondary_reply_length_limit, 250
  set :message_length_limit, 250

  set :minimum_submit_interval, 10.seconds
  set :need_captcha_bound, 100
  set :reset_submit_counter_interval, 7.hours

  set :redis_namespace, {
      problem_accepted_submissions: 'a/',
      problem_attempted_submissions: 'b/',
      problem_accepted_user_ids: 'c/',
      problem_attempted_user_ids: 'd/',
      problem_titles_hash: 'e/',
      problem_hot_problems: 'f/',

      user_accepted_submissions: 'g/',
      user_attempted_submissions: 'h/',
      user_accepted_problem_ids: 'i/',
      user_attempted_problem_ids: 'j/',
      user_unread_messages: 'k/',
      user_unread_notifications: 'l/',

      user_avatar_url: 'm/',
      user_rank_list: 'n/',
      user_handles_hash: 'o/',
      user_index: 'p/',
      normal_user_index: 'q/',
      topic_appear_users: 'r/',
      waiting_submissions: 's/',
      judge_machines: 't/'
  }
end
