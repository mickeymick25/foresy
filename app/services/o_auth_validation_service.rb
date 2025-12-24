# frozen_string_literal: true

# OauthValidationService
#
# Service responsible for OAuth data validation and extraction.
# Handles provider validation, payload validation, and OAuth data processing
# for external providers like GitHub and Google.
#
# This service extracts validation logic from OauthController to reduce
# complexity and improve maintainability.
#
# Supports two OAuth flows:
# 1. Traditional OmniAuth flow (browser redirect) - uses request.env['omniauth.auth']
# 2. API flow (frontend sends code) - exchanges code via OAuthCodeExchangeService
#
# SECURITY NOTE - CSRF Protection:
# ---------------------------------
# In the API flow (code exchange), CSRF protection via 'state' parameter must be
# handled by the FRONTEND application:
#
# 1. Frontend generates a random 'state' before redirecting to OAuth provider
# 2. Frontend stores the 'state' (e.g., in sessionStorage)
# 3. After OAuth redirect, frontend verifies the returned 'state' matches
# 4. Only if state matches, frontend sends the 'code' to this API
#
# The API can optionally receive and log the 'state' for audit purposes,
# but the primary CSRF validation is the frontend's responsibility in this flow.
#
# For traditional OmniAuth browser flow, CSRF is handled by OmniAuth's session.
class OAuthValidationService
  SUPPORTED_PROVIDERS = %w[google_oauth2 github].freeze

  # Validate that the provider is supported
  def self.valid_provider?(provider)
    SUPPORTED_PROVIDERS.include?(provider.to_s)
  end

  # Validate the callback payload according to Feature Contract
  # @param code [String] Authorization code from OAuth provider
  # @param redirect_uri [String] Redirect URI used in the OAuth flow
  # @param state [String, nil] Optional CSRF state token (for audit logging)
  # @return [Hash] Validation result with :valid or :error key
  #
  # SECURITY: The 'state' parameter is logged for audit purposes.
  # Primary CSRF validation should be done by the frontend before calling this API.
  def self.validate_callback_payload(code:, redirect_uri:, state: nil)
    if code.blank?
      Rails.logger.warn '[OAuth] Callback received without authorization code'
      return { error: 'missing_code' }
    elsif redirect_uri.blank?
      Rails.logger.warn '[OAuth] Callback received without redirect_uri'
      return { error: 'missing_redirect_uri' }
    end

    # Log state for audit (presence indicates frontend CSRF check was done)
    if state.present?
      Rails.logger.info '[OAuth] State parameter received (CSRF token present)'
    else
      Rails.logger.info '[OAuth] No state parameter (frontend should verify CSRF)'
    end

    { valid: true, code: code, redirect_uri: redirect_uri, state: state }
  end

  # Validate OAuth data completeness according to Feature Contract
  def self.validate_oauth_data(auth)
    return { error: 'missing_auth_data' } if auth.blank?

    provider = extract_provider(auth)
    uid = extract_uid(auth)
    info = extract_info(auth)
    email = extract_info_field(info, :email)

    validation_result = validate_oauth_fields(provider, uid, email)
    return validation_result if validation_result[:error]

    build_oauth_data_hash(provider, uid, email, info)
  end

  # Build OAuth data hash with validated fields
  def self.build_oauth_data_hash(provider, uid, email, info)
    {
      valid: true,
      data: {
        provider: provider,
        uid: uid,
        email: email,
        name: extract_info_field(info, :name),
        nickname: extract_info_field(info, :nickname)
      }
    }
  end

  # Extract OAuth data from request environment or exchange code
  # Supports both OmniAuth flow and direct API code exchange
  def self.extract_oauth_data(request, provider: nil, code: nil, redirect_uri: nil)
    # First, try OmniAuth flow (browser redirect)
    omniauth_data = request.env['omniauth.auth'] || Rails.application.env_config['omniauth.auth']
    return omniauth_data if omniauth_data.present?

    # If no OmniAuth data, try API code exchange flow
    return nil if code.blank? || provider.blank? || redirect_uri.blank?

    begin
      OAuthCodeExchangeService.exchange(
        provider: provider,
        code: code,
        redirect_uri: redirect_uri
      )
    rescue OAuthCodeExchangeService::ExchangeError => e
      Rails.logger.error "OAuth code exchange failed: #{e.message}"
      nil
    end
  end

  # Extract info field from OAuth info hash
  def self.extract_info_field(info, field)
    return nil if info.blank?

    if info.respond_to?(field)
      info.send(field)
    else
      info[field] || info[field.to_s]
    end
  end

  def self.extract_provider(auth)
    auth.respond_to?(:provider) ? auth.provider : (auth[:provider] || auth['provider'])
  end

  def self.extract_uid(auth)
    auth.respond_to?(:uid) ? auth.uid : (auth[:uid] || auth['uid'])
  end

  def self.extract_info(auth)
    auth.respond_to?(:info) ? auth.info : (auth[:info] || auth['info'])
  end

  def self.validate_oauth_fields(provider, uid, email)
    if provider.blank?
      Rails.logger.error '[OAuth] Validation failed: missing provider'
      return { error: 'missing_provider' }
    end

    if uid.blank?
      Rails.logger.error "[OAuth] Validation failed: missing uid for provider #{provider}"
      return { error: 'missing_uid' }
    end

    if email.blank?
      Rails.logger.error "[OAuth] Validation failed: missing email for provider #{provider}, uid #{uid}"
      return { error: 'missing_email' }
    end

    Rails.logger.info "[OAuth] Validation successful: provider=#{provider}, uid=#{uid}"
    { valid: true }
  end
end
