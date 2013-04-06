$redis = Redis.new db: 1

User.init_handles_hash
User.init_blocked_users
User.init_user_index
User.init_normal_user_index
Problem.init_titles_hash
Submission.init_waiting_submissions
