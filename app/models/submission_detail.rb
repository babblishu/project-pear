class SubmissionDetail < ActiveRecord::Base
  acts_as_cached version: 1, expires_in: 1.week

  attr_accessible :program
  attr_accessible :result

  validates :program, presence: true
end
