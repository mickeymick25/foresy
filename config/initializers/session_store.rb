# frozen_string_literal: true

# config/initializers/session_store.rb

# Configure session store with environment-dependent security settings
# For OAuth with OmniAuth (Google, GitHub), we need same_site: :none in production
# But in development without HTTPS, we use more permissive settings

Rails.application.config.session_store :cookie_store,
                                       key: 'foresy_session',
                                       same_site: Rails.env.production? ? :none : :lax,
                                       secure: Rails.env.production?,
                                       httponly: true,
                                       expire_after: 2.hours
