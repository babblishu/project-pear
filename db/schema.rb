# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130304032753) do

  create_table "messages", :force => true do |t|
    t.integer  "user_from",                                    :null => false
    t.integer  "user_to",                                      :null => false
    t.boolean  "read",                      :default => false, :null => false
    t.string   "content",    :limit => 250,                    :null => false
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
  end

  add_index "messages", ["user_from"], :name => "index_messages_on_user_from"
  add_index "messages", ["user_to", "read"], :name => "index_messages_on_user_to_and_read"
  add_index "messages", ["user_to"], :name => "index_messages_on_user_to"

  create_table "notifications", :force => true do |t|
    t.integer  "user_id",                       :null => false
    t.text     "content",                       :null => false
    t.boolean  "read",       :default => false, :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  add_index "notifications", ["user_id", "read"], :name => "index_notifications_on_user_id_and_read"
  add_index "notifications", ["user_id"], :name => "index_notifications_on_user_id"

  create_table "primary_replies", :force => true do |t|
    t.integer  "topic_id",                                         :null => false
    t.integer  "user_id",                                          :null => false
    t.text     "content",                                          :null => false
    t.text     "program"
    t.string   "language",        :limit => 10
    t.boolean  "enable_markdown",               :default => false, :null => false
    t.boolean  "hidden",                        :default => false, :null => false
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
  end

  add_index "primary_replies", ["created_at"], :name => "index_primary_replies_on_created_at"
  add_index "primary_replies", ["topic_id"], :name => "index_primary_replies_on_topic_id"

  create_table "problem_contents", :force => true do |t|
    t.integer  "problem_id",                                              :null => false
    t.string   "time_limit",             :limit => 20,                    :null => false
    t.string   "memory_limit",           :limit => 20,                    :null => false
    t.text     "background",                           :default => "",    :null => false
    t.text     "description",                          :default => "",    :null => false
    t.text     "input",                                :default => "",    :null => false
    t.text     "output",                               :default => "",    :null => false
    t.text     "sample_illustration",                  :default => "",    :null => false
    t.text     "additional_information",               :default => "",    :null => false
    t.boolean  "enable_markdown",                      :default => true,  :null => false
    t.boolean  "enable_latex",                         :default => false, :null => false
    t.text     "program",                              :default => "",    :null => false
    t.string   "language",               :limit => 10
    t.text     "solution",                             :default => "",    :null => false
    t.datetime "created_at",                                              :null => false
    t.datetime "updated_at",                                              :null => false
  end

  add_index "problem_contents", ["problem_id"], :name => "index_problem_contents_on_problem_id"

  create_table "problems", :force => true do |t|
    t.string   "status",              :limit => 20,  :default => "hidden", :null => false
    t.string   "title",               :limit => 20,                        :null => false
    t.string   "source",              :limit => 100, :default => "",       :null => false
    t.datetime "test_data_timestamp"
    t.datetime "created_at",                                               :null => false
    t.datetime "updated_at",                                               :null => false
  end

  add_index "problems", ["status"], :name => "index_problems_on_status"

  create_table "problems_tags", :force => true do |t|
    t.integer "problem_id", :null => false
    t.integer "tag_id",     :null => false
  end

  add_index "problems_tags", ["problem_id"], :name => "index_problems_tags_on_problem_id"
  add_index "problems_tags", ["tag_id"], :name => "index_problems_tags_on_tag_id"

  create_table "sample_test_data", :force => true do |t|
    t.text     "input",      :null => false
    t.text     "output",     :null => false
    t.integer  "problem_id", :null => false
    t.integer  "case_no",    :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "sample_test_data", ["problem_id"], :name => "index_sample_test_data_on_problem_id"

  create_table "secondary_replies", :force => true do |t|
    t.integer  "primary_reply_id",                                   :null => false
    t.integer  "user_id",                                            :null => false
    t.string   "content",          :limit => 250,                    :null => false
    t.boolean  "hidden",                          :default => false, :null => false
    t.datetime "created_at",                                         :null => false
    t.datetime "updated_at",                                         :null => false
  end

  add_index "secondary_replies", ["created_at"], :name => "index_secondary_replies_on_created_at"
  add_index "secondary_replies", ["primary_reply_id"], :name => "index_secondary_replies_on_primary_reply_id"

  create_table "submissions", :force => true do |t|
    t.string   "remote_ip",   :limit => 30
    t.text     "program",                                          :null => false
    t.string   "language",    :limit => 10,                        :null => false
    t.string   "platform",    :limit => 20,                        :null => false
    t.integer  "user_id",                                          :null => false
    t.integer  "problem_id",                                       :null => false
    t.integer  "score"
    t.string   "status",      :limit => 20, :default => "waiting", :null => false
    t.text     "result"
    t.integer  "time_used"
    t.integer  "memory_used"
    t.integer  "code_size",                                        :null => false
    t.integer  "code_length",                                      :null => false
    t.boolean  "share",                     :default => false,     :null => false
    t.boolean  "hidden",                    :default => false,     :null => false
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
  end

  add_index "submissions", ["created_at"], :name => "index_submissions_on_created_at"
  add_index "submissions", ["language", "platform", "hidden"], :name => "index_submissions_on_language_and_platform_and_hidden"
  add_index "submissions", ["language"], :name => "index_submissions_on_language"
  add_index "submissions", ["platform", "status"], :name => "index_submissions_on_platform_and_status"
  add_index "submissions", ["platform"], :name => "index_submissions_on_platform"
  add_index "submissions", ["problem_id"], :name => "index_submissions_on_problem_id"
  add_index "submissions", ["score", "status", "hidden", "problem_id"], :name => "index_submissions_on_score_and_status_and_hidden_and_problem_id"
  add_index "submissions", ["score", "status", "hidden", "user_id"], :name => "index_submissions_on_score_and_status_and_hidden_and_user_id"
  add_index "submissions", ["score", "status", "hidden"], :name => "index_submissions_on_score_and_status_and_hidden"
  add_index "submissions", ["score"], :name => "index_submissions_on_score"
  add_index "submissions", ["status", "hidden", "problem_id"], :name => "index_submissions_on_status_and_hidden_and_problem_id"
  add_index "submissions", ["status", "hidden", "user_id"], :name => "index_submissions_on_status_and_hidden_and_user_id"
  add_index "submissions", ["user_id"], :name => "index_submissions_on_user_id"

  create_table "tags", :force => true do |t|
    t.string   "name",       :limit => 20, :null => false
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
  end

  create_table "topics", :force => true do |t|
    t.string   "status",          :limit => 20, :default => "normal", :null => false
    t.integer  "user_id",                                             :null => false
    t.integer  "problem_id"
    t.string   "title",           :limit => 20,                       :null => false
    t.text     "content",                                             :null => false
    t.text     "program"
    t.string   "language",        :limit => 10
    t.boolean  "enable_markdown",               :default => false,    :null => false
    t.boolean  "top",                           :default => false,    :null => false
    t.boolean  "no_reply",                      :default => false,    :null => false
    t.datetime "created_at",                                          :null => false
    t.datetime "updated_at",                                          :null => false
  end

  add_index "topics", ["created_at"], :name => "index_topics_on_created_at"
  add_index "topics", ["problem_id"], :name => "index_topics_on_problem_id"
  add_index "topics", ["status"], :name => "index_topics_on_status"
  add_index "topics", ["user_id"], :name => "index_topics_on_user_id"

  create_table "user_informations", :force => true do |t|
    t.integer  "user_id",                                          :null => false
    t.string   "real_name",      :limit => 20,                     :null => false
    t.string   "school",         :limit => 50,                     :null => false
    t.string   "email",          :limit => 50,                     :null => false
    t.string   "signature",      :limit => 100,                    :null => false
    t.boolean  "show_real_name",                :default => false, :null => false
    t.boolean  "show_school",                   :default => true,  :null => false
    t.boolean  "show_email",                    :default => true,  :null => false
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
  end

  add_index "user_informations", ["user_id"], :name => "index_user_informations_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "remote_ip",           :limit => 30
    t.string   "handle",              :limit => 15,                            :null => false
    t.string   "password_digest",                                              :null => false
    t.string   "role",                :limit => 20, :default => "normal_user", :null => false
    t.boolean  "blocked",                           :default => false,         :null => false
    t.datetime "last_submit",                                                  :null => false
    t.integer  "submit_times",                      :default => 0,             :null => false
    t.boolean  "need_captcha",                      :default => false,         :null => false
    t.datetime "created_at",                                                   :null => false
    t.datetime "updated_at",                                                   :null => false
    t.string   "avatar_file_name"
    t.string   "avatar_content_type"
    t.integer  "avatar_file_size"
    t.datetime "avatar_updated_at"
  end

  add_index "users", ["handle"], :name => "index_users_on_handle"

end
