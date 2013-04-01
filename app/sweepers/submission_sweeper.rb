class SubmissionSweeper < ActionController::Caching::Sweeper
  observe Submission
  def after_update(submission)
    total_page = (Problem.status_list_count(submission.problem) - 1) / APP_CONFIG.page_size[:problem_status_list] + 1
    total_page = 1 if total_page == 0
    1.upto(total_page) do |x|
      expire_action controller: 'problems', action: 'status', problem_id: submission.problem.id.to_s, page: x.to_s
    end
    submission.problem.clear_counter_cache
  end
end
