class ProblemContent < ActiveRecord::Base
  attr_accessible :time_limit
  attr_accessible :memory_limit
  attr_accessible :background
  attr_accessible :description
  attr_accessible :input
  attr_accessible :output
  attr_accessible :sample_illustration
  attr_accessible :additional_information
  attr_accessible :enable_markdown
  attr_accessible :enable_latex
  attr_accessible :program
  attr_accessible :language
  attr_accessible :solution

  validates :time_limit, presence: true
  validates :memory_limit, presence: true
  validates :time_limit, length: { maximum: 20 }
  validates :memory_limit, length: { maximum: 20 }
  validates :language, inclusion: { in: APP_CONFIG.program_languages.keys.map(&:to_s) << nil }
end
