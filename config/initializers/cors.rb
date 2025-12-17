# frozen_string_literal: true

# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['FRONTEND_URL'] || 'http://localhost:3000'

    resource '*',
             headers: :any,
             credentials: true,
             methods: %i[get post options delete put patch],
             expose: ['Authorization']
  end
end
