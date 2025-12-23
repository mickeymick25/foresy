# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

# OAuthCodeExchangeService
#
# Service responsible for exchanging OAuth authorization codes with providers.
# This enables frontend applications to send the authorization code to the API,
# which then exchanges it for user data with Google/GitHub.
#
# Flow:
# 1. Frontend redirects user to Google/GitHub
# 2. User authorizes and is redirected back to frontend with a code
# 3. Frontend sends code to API: POST /api/v1/auth/:provider/callback
# 4. This service exchanges the code with the provider for tokens
# 5. This service fetches user info from the provider
# 6. API returns JWT token to frontend
#
# Supported providers:
# - google_oauth2: Google OAuth 2.0
# - github: GitHub OAuth
class OAuthCodeExchangeService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USERINFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  GITHUB_TOKEN_URL = 'https://github.com/login/oauth/access_token'
  GITHUB_USERINFO_URL = 'https://api.github.com/user'
  GITHUB_EMAILS_URL = 'https://api.github.com/user/emails'

  class ExchangeError < StandardError; end

  # Exchange authorization code for user data
  # @param provider [String] OAuth provider (google_oauth2 or github)
  # @param code [String] Authorization code from provider
  # @param redirect_uri [String] Redirect URI used in the OAuth flow
  # @return [OmniAuth::AuthHash] User data in OmniAuth format
  def self.exchange(provider:, code:, redirect_uri:)
    case provider.to_s
    when 'google_oauth2'
      exchange_google(code, redirect_uri)
    when 'github'
      exchange_github(code, redirect_uri)
    else
      raise ExchangeError, "Unsupported provider: #{provider}"
    end
  end

  # Exchange Google authorization code
  def self.exchange_google(code, redirect_uri)
    # Step 1: Exchange code for access token
    token_response = google_token_request(code, redirect_uri)
    access_token = token_response['access_token']

    raise ExchangeError, 'Failed to obtain Google access token' if access_token.blank?

    # Step 2: Fetch user info
    user_info = google_userinfo_request(access_token)

    # Step 3: Build OmniAuth-compatible hash
    build_auth_hash({
                      provider: 'google_oauth2',
                      uid: user_info['id'],
                      email: user_info['email'],
                      name: user_info['name'],
                      image: user_info['picture']
                    })
  end

  # Exchange GitHub authorization code
  def self.exchange_github(code, redirect_uri)
    # Step 1: Exchange code for access token
    token_response = github_token_request(code, redirect_uri)
    access_token = token_response['access_token']

    if access_token.blank?
      raise ExchangeError,
            "Failed to obtain GitHub access token: #{token_response['error_description']}"
    end

    # Step 2: Fetch user info
    user_info = github_userinfo_request(access_token)

    # Step 3: Fetch primary email (may not be in user_info)
    email = user_info['email'] || github_primary_email(access_token)

    raise ExchangeError, 'GitHub account has no public email' if email.blank?

    # Step 4: Build OmniAuth-compatible hash
    build_auth_hash({
                      provider: 'github',
                      uid: user_info['id'].to_s,
                      email: email,
                      name: user_info['name'] || user_info['login'],
                      nickname: user_info['login'],
                      image: user_info['avatar_url']
                    })
  end

  # Google token exchange request
  def self.google_token_request(code, redirect_uri)
    uri = URI.parse(GOOGLE_TOKEN_URL)
    response = Net::HTTP.post_form(uri, {
                                     code: code,
                                     client_id: ENV.fetch('GOOGLE_CLIENT_ID', nil),
                                     client_secret: ENV.fetch('GOOGLE_CLIENT_SECRET', nil),
                                     redirect_uri: redirect_uri,
                                     grant_type: 'authorization_code'
                                   })

    parse_json_response(response, 'Google token exchange')
  end

  # Google user info request
  def self.google_userinfo_request(access_token)
    uri = URI.parse(GOOGLE_USERINFO_URL)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"

    response = perform_https_request(uri, request)
    parse_json_response(response, 'Google user info')
  end

  # GitHub token exchange request
  def self.github_token_request(code, redirect_uri)
    uri = URI.parse(GITHUB_TOKEN_URL)
    request = Net::HTTP::Post.new(uri)
    request['Accept'] = 'application/json'
    request.set_form_data({
                            code: code,
                            client_id: ENV.fetch('LOCAL_GITHUB_CLIENT_ID', nil),
                            client_secret: ENV.fetch('LOCAL_GITHUB_CLIENT_SECRET', nil),
                            redirect_uri: redirect_uri
                          })

    response = perform_https_request(uri, request)
    parse_json_response(response, 'GitHub token exchange')
  end

  # GitHub user info request
  def self.github_userinfo_request(access_token)
    uri = URI.parse(GITHUB_USERINFO_URL)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'Foresy-API'

    response = perform_https_request(uri, request)
    parse_json_response(response, 'GitHub user info')
  end

  # Fetch primary email from GitHub (when email is private)
  def self.github_primary_email(access_token)
    uri = URI.parse(GITHUB_EMAILS_URL)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'Foresy-API'

    response = perform_https_request(uri, request)
    emails = parse_json_response(response, 'GitHub emails')

    # Find primary email
    primary = emails.find { |e| e['primary'] && e['verified'] }
    primary&.fetch('email', nil)
  end

  # Perform HTTPS request
  def self.perform_https_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10
    http.request(request)
  end

  # Parse JSON response with error handling
  def self.parse_json_response(response, context)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "#{context} failed: #{response.code} - #{response.body}"
      raise ExchangeError, "#{context} failed with status #{response.code}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "#{context} JSON parse error: #{e.message}"
    raise ExchangeError, "#{context} returned invalid JSON"
  end

  # Build OmniAuth-compatible AuthHash
  # @param data [Hash] OAuth user data with keys: provider, uid, email, name, nickname, image
  def self.build_auth_hash(data)
    OmniAuth::AuthHash.new(
      provider: data[:provider],
      uid: data[:uid],
      info: OmniAuth::AuthHash::InfoHash.new(
        email: data[:email],
        name: data[:name],
        nickname: data[:nickname],
        image: data[:image]
      )
    )
  end
end
