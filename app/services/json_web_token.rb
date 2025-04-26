class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base
  DEFAULT_EXPIRATION = 1.hour
  REFRESH_EXPIRATION = 7.days

  def self.encode(payload, exp = DEFAULT_EXPIRATION.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new decoded
  rescue
    nil
  end

  def self.refresh_token(user_id)
    encode({ user_id: user_id }, REFRESH_EXPIRATION.from_now)
  end
end 