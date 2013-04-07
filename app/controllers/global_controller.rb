class GlobalController < ApplicationController
  before_filter :require_login, only: [ :captcha_verify ]
  before_filter :require_admin, only: [ :add_problem_help, :headers_test, :judge_machines ]

  def home
    @role = @current_user ? @current_user.role : 'normal_user'
    @now = Time.now
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

  def headers_test
  end

  def judge_machines
  end
end
