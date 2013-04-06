class GlobalController < ApplicationController
  before_filter :require_login, only: [ :captcha_verify ]
  before_filter :require_admin, only: [ :add_problem_help ]

  caches_action :faq, layout: false
  caches_action :add_problem_help, layout: false
  caches_action :markdown_help, layout: false

  def home
    @role = @current_user ? @current_user.role : 'normal_user'
    @now = Time.now
  end

  def faq
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

  def ip_test
  end
end
