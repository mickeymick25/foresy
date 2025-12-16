# frozen_string_literal: true

# config/initializers/session_store.rb

Rails.application.config.session_store :cookie_store,
                                       key: 'foresy_session',
                                       same_site: :none,
                                       secure: true,
                                       httponly: true,
                                       expire_after: 2.hours
