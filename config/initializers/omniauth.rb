# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV.fetch('GOOGLE_CLIENT_ID', nil),
           ENV.fetch('GOOGLE_CLIENT_SECRET', nil),
           {
             scope: 'email,profile',
             prompt: 'select_account'
           }

  provider :github,
           ENV.fetch('LOCAL_GITHUB_CLIENT_ID', nil),
           ENV.fetch('LOCAL_GITHUB_CLIENT_SECRET', nil),
           {
             scope: 'user:email'
           }
end

OmniAuth.config.allowed_request_methods = %i[post get]
OmniAuth.config.silence_get_warning = true
