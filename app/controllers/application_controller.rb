# frozen_string_literal: true

# ApplicationController
#
# Base controller from which all other API controllers inherit.
# Handles global configurations and shared behaviors.
# Authentication is provided by the Authenticatable concern.
# Error rendering is provided by the StandardizedError concern (Phase 1.9).
class ApplicationController < ActionController::API
  include Authenticatable
  include StandardizedError
end
