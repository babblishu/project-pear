ProjectPear::Application.routes.draw do
  captcha_route

  get 'ip_test' => 'global#ip_test'

  root :to => 'global#home'

  get 'captcha_verify' => 'global#captcha_verify'
  get 'captcha_verify/submit' => 'global#captcha_verify_submit'

  get 'login' => 'users#login'
  get 'logout' => 'users#logout'

  get 'register' => 'users#register'
  post 'users/create' => 'users#create'

  get 'markdown' => 'global#markdown_help'

  get 'faq' => 'faq#show'
  get 'faq/new' => 'faq#new'
  get 'faq/edit/:faq_id' => 'faq#edit', faq_id: /\d+/, as: 'faq_edit'
  post 'faq/create' => 'faq#create'
  post 'faq/update/:faq_id' => 'faq#update', faq_id: /\d+/, as: 'faq_update'
  get 'faq/delete/:faq_id' => 'faq#delete', faq_id: /\d+/, as: 'faq_delete'
  get 'faq/swap/:faq_id_1/:faq_id_2' => 'faq#swap', faq_id_1: /\d+/, faq_id_2: /\d+/, as: 'faq_swap'

  get 'discuss/list(/:page)' => 'discuss#list', page: /\d+/, as: 'discuss_list'
  get 'discuss/:topic_id/show(/:page)' => 'discuss#show', topic_id: /\d+/, page: /\d+/, as: 'discuss_show'
  post 'discuss/topic/:operation' => 'discuss#topic', operation: /create|update/, as: 'discuss_topic'
  post 'discuss/primary_reply/:operation' => 'discuss#primary_reply',
       operation: /create|update/, as: 'discuss_primary_reply'
  post 'discuss/secondary_reply/:operation' => 'discuss#secondary_reply',
       operation: /create|update/, as: 'discuss_secondary_reply'
  get 'discuss/admin/:operation' => 'discuss#admin', operation: /show|hide/, as: 'discuss_admin'
  get 'discuss/locate/:type/:id' => 'discuss#locate', type: /primary_reply|secondary_reply/, id: /\d+/,
      as: 'discuss_locate'
  get 'discuss/download_code/:type/:id' => 'discuss#download_code', type: /topic|primary_reply/, id: /\d+/,
      as: 'discuss_download_code'

  get 'notifications' => 'messages#notifications', as: 'notifications'
  get 'messages/list(/:page)' => 'messages#list', page: /\d+/, as: 'messages_list'
  get 'messages/show/:handle' => 'messages#show', handle: /[a-z0-9\._]{3,15}/i, as: 'messages_show'
  post 'messages/create/:handle' => 'messages#create', handle: /[a-z0-9\._]{3,15}/i, as: 'messages_create'

  get 'problems/:problem_id/show' => 'problems#show', problem_id: /\d{4}/, as: 'problems_show'
  get 'problems/:problem_id/status/:page' => 'problems#status', problem_id: /\d{4}/,
      page: /\d+/, as: 'problems_status'
  get 'problems/list(/:page)' => 'problems#list', page: /\d+/, as: 'problems_list'
  get 'problems/:problem_id/edit' => 'problems#edit', problem_id: /\d{4}/, as: 'problems_edit'
  post 'problems/create' => 'problems#create'
  post 'problems/:problem_id/update' => 'problems#update', problem_id: /\d{4}/, as: 'problems_update'
  post 'problems/:problem_id/upload_test_data' => 'problems#upload_test_data',
       problem_id: /\d{4}/, as: 'problems_upload_test_data'
  get 'problems/:problem_id/download_test_data' => 'problems#download_test_data',
      problem_id: /\d{4}/, as: 'problems_download_test_data'
  get 'problems/:problem_id/rejudge' => 'problems#rejudge', problem_id: /\d{4}/, as: 'problems_rejudge'
  get 'search_problem' => 'problems#search', as: 'problems_search'
  get 'problems/help' => 'global#add_problem_help'

  post 'submissions/create' => 'submissions#create'
  get 'submissions/list(/:page)' => 'submissions#list', page: /\d+/, as: 'submissions_list'
  get 'submissions/:submission_id/result' => 'submissions#result', submission_id: /\d+/, as: 'submissions_result'
  get 'submissions/:submission_id/download' => 'submissions#download', submission_id: /\d+/, as: 'submissions_download'
  get 'submissions/:submission_id/share' => 'submissions#share', submission_id: /\d+/, as: 'submissions_share'
  get 'submissions/:submission_id/show' => 'submissions#show', submission_id: /\d+/, as: 'submissions_show'
  get 'submissions/:submission_id/hide' => 'submissions#hide', submission_id: /\d+/, as: 'submissions_hide'
  get 'submissions/:submission_id/rejudge' => 'submissions#rejudge', submission_id: /\d+/, as: 'submissions_rejudge'
  get 'submissions/get_waiting/:platform' => 'submissions#get_waiting',
      platform: Regexp.new(APP_CONFIG.judge_platforms.keys.map(&:to_s).join('|'))
  post 'submissions/:submission_id/receive_result' => 'submissions#receive_result', submission_id: /\d+/

  get 'users/:handle/edit' => 'users#edit', handle: /[a-z0-9\._]{3,15}/i, as: 'users_edit'
  post 'users/:handle/update' => 'users#update', handle: /[a-z0-9\._]{3,15}/i, as: 'users_update'
  get 'users/:handle/admin/:operation' => 'users#admin', handle: /[a-z0-9\._]{3,15}/i,
      operation: /upto_admin|block_user|unblock_user/, as: 'users_admin'
  get 'edit_password' => 'users#edit_password', as: 'users_edit_password'
  post 'update_password' => 'users#update_password', as: 'users_update_password'
  get 'users/:handle' => 'users#show', handle: /[a-z0-9\._]{3,15}/i, as: 'users_show'
  get 'users/:handle/compare' => 'users#compare', handle: /[a-z0-9\._]{3,15}/i, as: 'users_compare'
  get 'search_user' => 'users#search', as: 'users_search'
  get 'rank/:span(/:page)' => 'users#list', span: /all|year|month|week|day/, page: /\d+/, as: 'rank'
  get 'users/add_advanced_users' => 'users#add_advanced_users'
  post 'users/admin_advanced_users/:operation' => 'users#admin_advanced_users',
      operation: /add|remove/, as: 'users_admin_advanced_users'
end
