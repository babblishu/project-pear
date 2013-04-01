class ProblemSweeper < ActionController::Caching::Sweeper
  observe Problem

  def after_create(problem)
    Problem.clear_list_cache
  end

  def after_update(problem)
    clear_problems_list_cache
    expire_fragment controller: 'problems', action: 'show', problem_id: problem.id.to_s, action_suffix: 'main'
    expire_fragment controller: 'problems', action: 'show', problem_id: problem.id.to_s, action_suffix: 'toolbar'
    expire_fragment controller: 'problems', action: 'list', action_suffix: 'filter_dialog'
  end

end
