# frozen_string_literal: true

# ApplicationError
#
# Base module for application-specific errors that should always be handled
# by the ErrorRenderable rescue_from, even in development/test environments.
# This allows testing of error handling behavior while still exposing
# unexpected errors for debugging.
#
# Examples:
#   raise ApplicationError::Base, 'Something went wrong'
#   raise ApplicationError::InternalServerError, 'Database connection failed'
module ApplicationError
  # Base class for application-specific errors
  # This is the main exception class that should be used for general application errors
  class Base < StandardError
    # No additional functionality needed - inherits from StandardError
  end

  # Specific application error types as nested classes
  class InternalServerError < Base; end
  class ValidationError < Base; end
  class AuthorizationError < Base; end
end
