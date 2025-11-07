# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    rescue_from JWT::DecodeError, with: lambda {
      render json: { error: 'Unauthorized', message: 'Invalid token' }, status: :unauthorized
    }
    rescue_from JWT::ExpiredSignature, with: lambda {
      render json: { error: 'Unauthorized', message: 'Token has expired' }, status: :unauthorized
    }
  end
end
