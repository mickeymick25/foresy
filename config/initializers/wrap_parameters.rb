# frozen_string_literal: true

# Parameter wrapping for JSON API requests
# Automatically wraps flat JSON bodies under the controller's resource name
# e.g., {"email": "...", "password": "..."} → {"user": {"email": "...", "password": "..."}}
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: [:json]
end
