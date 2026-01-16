# frozen_string_literal: true

# ApplicationController
#
# Base controller from which all other API controllers inherit.
# Handles global configurations and shared behaviors.
# Authentication is provided by the Authenticatable concern.
# Error rendering is provided by the ErrorRenderable concern.
class ApplicationController < ActionController::API
  before_action :force_json_format
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error

  include Authenticatable
  include ErrorRenderable

  private

  def force_json_format
    Rails.logger.info "[APPLICATION_CONTROLLER] force_json_format reached"
    request.format = :json
  end

  def handle_parse_error
    render json: { error: 'Invalid parameters' }, status: :bad_request
  end
end
