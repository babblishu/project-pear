class FaqController < ApplicationController
  before_filter :require_admin, only: [ :edit, :new, :create, :update, :delete, :swap ]

  def show
  end

  def edit
    @faq = Faq.find_by_id! params[:faq_id]
  end

  def new
  end

  def create
    faq = Faq.new params[:faq]
    if faq.title.empty?
      return render json: { success: false, notice: t('faq.create.empty_title') }
    end
    faq.rank = (Faq.maximum(:rank) || 0) + 1
    faq.save
    clear_show_cache
    render json: { success: true, redirect_url: faq_url }
  end

  def update
    faq = Faq.find_by_id! params[:faq_id]
    faq.attributes = params[:faq]
    if faq.title.empty?
      return render json: { success: false, notice: t('faq.update.empty_title') }
    end
    faq.save
    clear_show_cache
    render json: { success: true, redirect_url: faq_url }
  end

  def delete
    faq = Faq.find_by_id! params[:faq_id]
    faq.destroy
    clear_show_cache
    redirect_to faq_url
  end

  def swap
    faq1 = Faq.find_by_id! params[:faq_id_1]
    faq2 = Faq.find_by_id! params[:faq_id_2]
    raise AppExceptions::InvalidOperation if faq1.id == faq2.id
    tmp = faq1.rank
    faq1.rank = faq2.rank
    faq2.rank = tmp
    faq1.save
    faq2.save
    clear_show_cache
    redirect_to faq_url
  end

  private
  def clear_show_cache
    expire_fragment action: 'show', action_suffix: 'normal'
    expire_fragment action: 'show', action_suffix: 'admin'
  end
end
