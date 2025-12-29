# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

require 'redis'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  # Application class for initializing the Rails application.
  # This class is responsible for setting up the configuration defaults
  # and loading the necessary gems, middleware, and other resources.
  #
  # It inherits from `Rails::Application`, which provides the core Rails setup,
  # such as configuring the time zone, autoload paths, and any environment-specific settings.
  #
  # For instance:
  # - `config.load_defaults` sets the default configuration for the Rails version.
  # - `config.autoload_lib` customizes the autoload paths for libraries.
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Session middleware configuration for OmniAuth compatibility
    # OmniAuth requires session support to store CSRF state during OAuth flow
    # Authentication remains stateless via JWT tokens - session is only for OAuth
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: '_foresy_session'

    # Rate limiting middleware for FC-05 Feature Contract
    # Protects authentication endpoints from brute force attacks
    # - POST /api/v1/auth/login (5 requests/minute)
    # - POST /api/v1/auth/signup (3 requests/minute)
    # - POST /api/v1/auth/refresh (10 requests per minute)
    # Rate limiting is handled directly in controllers using RateLimitService
    require_relative '../app/services/rate_limit_service'
    # This provides IP-based rate limiting for authentication endpoints:
    # - POST /api/v1/auth/login: 5 requests per minute
    # - POST /api/v1/signup: 3 requests per minute
    # - POST /api/v1/auth/refresh: 10 requests per minute
  end
end
