# frozen_string_literal: true

require 'jwt'

# JsonWebToken
#
# Service responsible for encoding and decoding JSON Web Tokens (JWT).
# Provides methods to generate access and refresh tokens used for user authentication.
#
# Constants:
# - SECRET_KEY: Used to sign and verify JWTs (based on Rails secret_key_base)
# - ACCESS_TOKEN_EXPIRATION: Default expiration time for access tokens (15 minutes)
# - REFRESH_TOKEN_EXPIRATION: Default expiration time for refresh tokens (30 days)
#
# Class Methods:
# - .encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now): Encodes a payload into a JWT token
# - .refresh_token(user_id): Creates a refresh token with extended expiration
# - .decode(token): Decodes a JWT token and returns its payload as a HashWithIndifferentAccess
#
# Example:
#   token = JsonWebToken.encode(user_id: 123)
#   payload = JsonWebToken.decode(token)
#
class JsonWebToken
  SECRET_KEY = Rails.application.secret_key_base
  ACCESS_TOKEN_EXPIRATION = 15.minutes
  REFRESH_TOKEN_EXPIRATION = 30.days

  def self.encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.refresh_token(user_id)
    payload = {
      user_id: user_id,
      refresh_exp: REFRESH_TOKEN_EXPIRATION.from_now.to_i
    }
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(decoded)
  end
end
