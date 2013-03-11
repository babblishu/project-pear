class GlobalController < ApplicationController
  before_filter :require_login, only: [ :captcha_verify ]
  before_filter :require_admin, only: [ :add_problem_help ]

  def home
    role = @current_user ? @current_user.role : 'normal_user'
    @discuss = Topic.list_for_role role, 1, 13
    today = Time.now.beginning_of_day
    @top_users = User.top_users today, 5
    @hot_problems = Problem.hot_problems today, role, 5
    if @current_user
      @today_accepted_problems = @current_user.accepted_problems today
      @today_submissions = @current_user.attempted_submissions today
    end
  end

  def faq
    @faq_active = true
  end

  def captcha_verify
    redirect_to root_url unless @current_user.need_captcha
  end

  def captcha_verify_submit
    redirect_to root_url unless @current_user.need_captcha
    if valid_captcha? params[:captcha]
      @current_user.update_attribute :need_captcha, false
      redirect_to root_url
    else
      redirect_to :back, notice: t('home.captcha_verify.wrong_captcha')
    end
  end

  def add_problem_help
  end

  def markdown_help
  end
end
