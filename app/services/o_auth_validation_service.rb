# frozen_string_literal: true

# OAuthValidationService
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
class OAuthValidationService
  SUPPORTED_PROVIDERS = %w[google_oauth2 github].freeze

  # Validate that the provider is supported
  def self.valid_provider?(provider)
    SUPPORTED_PROVIDERS.include?(provider.to_s)
  end

  # Validate the callback payload according to Feature Contract
  def self.validate_callback_payload(code:, redirect_uri:)
    if code.blank?
      return { error: 'missing_code' }
    elsif redirect_uri.blank?
      return { error: 'missing_redirect_uri' }
    end

    { valid: true, code: code, redirect_uri: redirect_uri }
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
    return { error: 'missing_provider' } if provider.blank?
    return { error: 'missing_uid' } if uid.blank?
    return { error: 'missing_email' } if email.blank?

    { valid: true }
  end
end
