class SampleTestData < ActiveRecord::Base
  belongs_to :problem
  attr_accessible :input
  attr_accessible :output
  attr_accessible :problem
  attr_accessible :case_no
end
