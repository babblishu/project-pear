module AppExceptions
  class InvalidOperation < StandardError; end
  class RequireLoginError < StandardError; end
  class NoPrivilegeError < StandardError; end
  class InvalidPageNumber < StandardError; end
  class InvalidUserHandle < StandardError; end
  class InvalidProblemId < StandardError; end
  class InvalidSubmissionId < StandardError; end
  class InvalidTopicId < StandardError; end
  class InvalidPrimaryReplyId < StandardError; end
  class InvalidSecondaryReplyId < StandardError; end
  class NoTestDataError < StandardError; end
end
