# frozen_string_literal: true

# config/initializers/deprecations.rb

Rails.application.configure do
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
end
