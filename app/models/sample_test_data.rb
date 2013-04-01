class SampleTestData < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  belongs_to :problem
  attr_accessible :input
  attr_accessible :output
  attr_accessible :problem
  attr_accessible :case_no
end
