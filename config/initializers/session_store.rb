# frozen_string_literal: true

# config/initializers/session_store.rb

# Session store configuration for Foresy API
#
# CONTEXT:
# - Foresy uses JWT stateless authentication for API endpoints
# - OmniAuth middleware requires a session to function (stores CSRF state)
# - We use a minimal cookie session ONLY for OmniAuth compatibility
#
# SECURITY CONSIDERATIONS:
# - Authentication is handled via JWT tokens in Authorization headers
# - The session is NOT used for user authentication
# - Session is only used internally by OmniAuth for OAuth flow
# - CSRF protection for OAuth is handled by OmniAuth's state parameter
#
# This configuration provides:
# - Minimal session support for OmniAuth middleware
# - No impact on JWT-based API authentication
# - Compatibility with stateless API design

Rails.application.config.session_store :cookie_store,
                                       key: '_foresy_session',
                                       same_site: :lax,
                                       secure: Rails.env.production?,
                                       expire_after: 1.hour
