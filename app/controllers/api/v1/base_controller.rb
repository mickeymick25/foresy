# frozen_string_literal: true

# Api::V1::BaseController
#
# Base controller for all API v1 endpoints.
# Inherits from ApplicationController and adds API v1 specific functionality.
#
# Includes:
# - Api::Deprecation: for handling deprecation headers
class Api::V1::BaseController < ApplicationController
  include Api::Deprecation

  # Add deprecation headers to all API v1 responses
  # Only endpoints configured in DEPRECATED_ENDPOINTS will have headers
  before_action :add_deprecation_headers

  # Override the build_endpoint_key to include the action name
  # This allows granular deprecation at action level if needed
  private

  def build_endpoint_key
    # Extract the resource name from controller path
    # e.g., 'api/v1/missions' -> 'missions'
    # This matches the keys in DEPRECATED_ENDPOINTS
    controller_path.gsub(%r{^api/v1/}, '')
  end
end
