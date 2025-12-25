# frozen_string_literal: true

# Helper pour gérer les variables d'environnement OAuth avec robustesse
def require_oauth_env(var_name, provider_name)
  value = ENV.fetch(var_name, nil)
  if value.nil? || value.empty?
    Rails.logger.warn '⚠️  OAuth Environment Variable Missing'
    Rails.logger.warn "Variable: #{var_name} for provider: #{provider_name}"
    Rails.logger.warn 'This provider will be disabled until configured.'
    return nil
  end
  value
end

# Configuration OmniAuth simple et robuste
Rails.application.config.middleware.use OmniAuth::Builder do
  # Configuration Google OAuth2
  google_client_id = require_oauth_env('GOOGLE_CLIENT_ID', 'Google OAuth2')
  google_client_secret = require_oauth_env('GOOGLE_CLIENT_SECRET', 'Google OAuth2')

  if google_client_id && google_client_secret
    provider :google_oauth2,
             google_client_id,
             google_client_secret,
             {
               scope: 'email,profile',
               prompt: 'select_account'
             }
  else
    Rails.logger.warn '🚫 Google OAuth2 disabled - Missing credentials'
  end

  # Configuration GitHub OAuth
  github_client_id = require_oauth_env('LOCAL_GITHUB_CLIENT_ID', 'GitHub OAuth')
  github_client_secret = require_oauth_env('LOCAL_GITHUB_CLIENT_SECRET', 'GitHub OAuth')

  if github_client_id && github_client_secret
    provider :github,
             github_client_id,
             github_client_secret,
             {
               scope: 'user:email'
             }
  else
    Rails.logger.warn '🚫 GitHub OAuth disabled - Missing credentials'
  end
end

# Configuration OmniAuth pour éviter les conflits avec les endpoints de santé
# Configurer OmniAuth pour ne pas exiger de session pour tous les endpoints
OmniAuth.config.allowed_request_methods = %i[post get]
OmniAuth.config.silence_get_warning = true

# IMPORTANT: Pour une API stateless, on désactive la vérification de session d'OmniAuth
# OmniAuth n'interceptera que les routes /auth/:provider
OmniAuth.config.request_validation_phase = nil

# Logging informatif au démarrage
Rails.logger.info '🔐 OmniAuth initialized successfully'

# Validation de configuration au démarrage (environnements dev/test)
if Rails.env.development? || Rails.env.test?
  Rails.logger.info '🔑 OAuth Configuration Check:'
  Rails.logger.info "  Google OAuth: #{ENV['GOOGLE_CLIENT_ID'].present? ? '✅ Configured' : '❌ Missing'}"
  Rails.logger.info "  GitHub OAuth: #{ENV['LOCAL_GITHUB_CLIENT_ID'].present? ? '✅ Configured' : '❌ Missing'}"
end
