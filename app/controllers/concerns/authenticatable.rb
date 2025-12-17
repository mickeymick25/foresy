# frozen_string_literal: true

# Authenticatable
#
# Concern that provides authentication functionality for controllers.
# Handles JWT token validation and user session management.
module Authenticatable
  extend ActiveSupport::Concern

  included do
  end
end
