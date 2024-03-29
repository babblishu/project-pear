SimpleConfig.for :application do
  unset :redis_namespace
  set :redis_namespace, {
      problem_accepted_submissions: 'problem/accepted_submissions/',
      problem_attempted_submissions: 'problem/attempted_submissions/',
      problem_accepted_user_ids: 'problem/accepted_user_ids/',
      problem_attempted_user_ids: 'problem/attempted_user_ids/',
      problem_titles_hash: 'problem/titles_hash/',
      problem_hot_problems: 'problem/hot_problems/',

      user_accepted_submissions: 'user/accepted_submissions/',
      user_attempted_submissions: 'user/attempted_submissions/',
      user_accepted_problem_ids: 'user/accepted_problem_ids/',
      user_attempted_problem_ids: 'user/attempted_problem_ids/',
      user_unread_messages: 'user/unread_messages/',
      user_unread_notifications: 'user/unread_notifications/',

      user_avatar_url: 'user/avatar_url/',
      user_rank_list: 'user/rank_list/',
      user_handles_hash: 'user/handles_hash/',
      user_index: 'user_index/',
      normal_user_index: 'normal_user_index/',
      topic_appear_users: 'topic/appear_users/',
      waiting_submissions: 'waiting_submissions/',
      judge_machines: 'judge/machines/'
  }
end
