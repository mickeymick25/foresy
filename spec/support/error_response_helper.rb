# frozen_string_literal: true

# Error Response Helper
#
# Helper methods for testing API error responses.
# Ensures consistent error structure across all endpoints.
#
# Usage:
#   expect_error_response(response, code: 'unauthorized', message: 'Invalid token')
#   expect_error_code(response, 'not_found')
#
module ErrorResponseHelper
  # Expects a standard error response structure
  # @param response [ActionDispatch::Response] The response object
  # @param code [String] Expected error code (e.g., 'unauthorized', 'not_found')
  # @param message [String, nil] Optional expected message
  def expect_error_response(response, code:, message: nil)
    data = JSON.parse(response.body)

    expect(data['error']).to be_a(Hash)
    expect(data['error']['code']).to eq(code)

    expect(data['error']['message']).to be_present if message.nil?
    expect(data['error']['message']).to eq(message) if message.present?
  end

  # Expects only the error code (when message is not important)
  # @param response [ActionDispatch::Response] The response object
  # @param code [String] Expected error code
  def expect_error_code(response, code)
    data = JSON.parse(response.body)

    expect(data['error']).to be_a(Hash)
    expect(data['error']['code']).to eq(code)
  end
end

RSpec.configure do |config|
  config.include ErrorResponseHelper, type: :request
end
