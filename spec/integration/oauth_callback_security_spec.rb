# frozen_string_literal: true

# 🔒 Security invariant spec: OAuth callback must not leak internal
# exception messages to the client.
#
# This spec characterizes the security fix for audit point C8
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The OauthController#callback rescued StandardError and called:
#   error_internal("OAuth callback error: #{e.message}")
# In non-production environments, error_internal passes the message
# through verbatim, leaking internal exception details to the client.
#
# Invariant: When an exception occurs in the OAuth flow, the JSON
# response must NOT contain the exception's message. A generic
# "internal error" message should be returned instead.

require 'rails_helper'

RSpec.describe 'OAuth callback exception non-disclosure', type: :request do
  describe 'POST /api/v1/auth/google/callback when the OAuth flow raises' do
    # We inject a specific sentinel exception message to verify it
    # does NOT appear in the response body.
    let(:sentinel_message) { 'SECRET_INTERNAL_DB_CONNECTION_FAILED_12345' }

    before do
      # Force execute_oauth_flow to raise with our sentinel message
      allow_any_instance_of(Api::V1::OauthController).to receive(:execute_oauth_flow)
        .and_raise(StandardError, sentinel_message)
    end

    it 'returns a 500 status code' do
      post '/api/v1/auth/google/callback', params: { code: 'fake_code', redirect_uri: 'http://localhost' }
      expect(response).to have_http_status(:internal_server_error)
    end

    it 'does not leak the exception message to the client' do
      post '/api/v1/auth/google/callback', params: { code: 'fake_code', redirect_uri: 'http://localhost' }
      expect(response.body).not_to include(sentinel_message)
    end

    it 'returns a generic error message without internal details' do
      post '/api/v1/auth/google/callback', params: { code: 'fake_code', redirect_uri: 'http://localhost' }
      parsed = JSON.parse(response.body)
      expect(parsed['message']).not_to include(sentinel_message)
      expect(parsed['message']).not_to include('OAuth callback error')
    end
  end
end
