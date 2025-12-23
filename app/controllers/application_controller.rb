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
end
