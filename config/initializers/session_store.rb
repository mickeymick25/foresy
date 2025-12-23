# frozen_string_literal: true

# config/initializers/session_store.rb

# Session store disabled - Foresy uses JWT stateless authentication
#
# RATIONALE:
# - Authentication is handled via JWT tokens in Authorization headers
# - No cookies are used for user authentication
# - This eliminates CSRF risk entirely
# - OAuth callbacks are handled internally by OmniAuth
# - SameSite: :none was configured for OAuth but not needed for auth
#
# SECURITY BENEFITS:
# - Eliminates CSRF attack surface completely
# - Simplifies authentication architecture
# - No session management overhead
# - Clear separation: JWT for auth, OmniAuth for OAuth flow

Rails.application.config.session_store :disabled
