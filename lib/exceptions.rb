module AppExceptions
  class InvalidOperation < StandardError; end
  class RequireLoginError < StandardError; end
  class NoPrivilegeError < StandardError; end
  class InvalidPageNumber < StandardError; end
end
