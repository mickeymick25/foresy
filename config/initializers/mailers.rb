# frozen_string_literal: true

# config/initializers/mailers.rb

Rails.application.configure do
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
end
