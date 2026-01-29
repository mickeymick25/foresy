# frozen_string_literal: true

# ApplicationError
#
# Base class for application-specific errors that should always be handled
# by the ErrorRenderable rescue_from, even in development/test environments.
# This allows testing of error handling behavior while still exposing
# unexpected errors for debugging.
#
# Examples:
#   raise ApplicationError, 'Something went wrong'
#   raise ApplicationError::InternalServerError, 'Database connection failed'
class ApplicationError < StandardError
  # No additional functionality needed - inherits from StandardError

  # Specific application error types as nested classes
  class InternalServerError < ApplicationError; end
  class ValidationError < ApplicationError; end
  class AuthorizationError < ApplicationError; end
  class GitLedgerError < ApplicationError; end
end
