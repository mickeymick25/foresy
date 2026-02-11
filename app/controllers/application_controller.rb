# frozen_string_literal: true

# ApplicationController
#
# Base controller from which all other API controllers inherit.
# Handles global configurations and shared behaviors.
# Authentication is provided by the Authenticatable concern.
# Error rendering is provided by the ErrorRenderable concern.
class ApplicationController < ActionController::API
  include Authenticatable
  include ErrorRenderable

  # TEMPORARY: Catch all exceptions to see the actual error causing 500
  rescue_from StandardError do |exception|
    Rails.logger.error '=' * 60
    Rails.logger.error "🔥 UNHANDLED EXCEPTION: #{exception.class}"
    Rails.logger.error "Message: #{exception.message}"
    Rails.logger.error '=' * 60
    Rails.logger.error 'Backtrace:'
    exception.backtrace.first(20).each { |line| Rails.logger.error "  #{line}" }
    Rails.logger.error '=' * 60
    raise exception
  end
end
