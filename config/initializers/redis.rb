if Rails.env.development?
  $redis = Redis.new db: 1
else
  $redis = Redis.new db: 1, driver: :hiredis
end

User.init_handles_hash
User.init_blocked_users
User.init_user_index
User.init_normal_user_index
Problem.init_titles_hash
Submission.init_waiting_submissions
