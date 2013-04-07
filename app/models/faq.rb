class Faq < ActiveRecord::Base
  attr_accessible :title
  attr_accessible :content
  attr_accessible :rank
end
