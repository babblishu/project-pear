class SubmissionDetail < ActiveRecord::Base
  attr_accessible :program
  attr_accessible :result

  validates :program, presence: true
end
