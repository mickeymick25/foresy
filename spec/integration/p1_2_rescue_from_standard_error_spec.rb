# frozen_string_literal: true

# 🔴 P1.2 — Stabilisation Runtime : conflit rescue_from StandardError
#
# This spec characterizes the fix for audit point C2
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# ApplicationController defines a rescue_from StandardError that RE-RAISES
# the exception (commented # TEMPORARY). This neutralizes the
# StandardizedError concern's handle_standard_error handler, which
# should format a proper JSON 500 response.
#
# Invariant: When a controller action raises StandardError, the response
# must be a JSON 500 with the standardized error format
# ({ code: "INTERNAL_SERVER_ERROR", message: ... }), not a re-raised
# exception or raw HTML error page.

require 'rails_helper'

RSpec.describe 'P1.2 — rescue_from StandardError conflict', type: :request do
  describe 'when a controller action raises StandardError' do
    # We stub MissionsController#index to raise StandardError, simulating
    # an unexpected internal error. The response should be a formatted
    # JSON 500, not a re-raised exception.
    before do
      allow_any_instance_of(Api::V1::MissionsController).to receive(:index)
        .and_raise(StandardError, 'Simulated internal error')
    end

    it 'returns a 500 status code (not a re-raised exception)' do
      user = create(:user, password: 'password123')
      token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]

      # In test env, if the exception is re-raised, Rails will either
      # propagate it (raising in the test) or render a 500.
      # We expect a 500 response, not an exception propagation.
      begin
        get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }
        expect(response).to have_http_status(:internal_server_error)
      rescue StandardError => e
        raise "Expected a 500 response, but the exception was re-raised: #{e.class} - #{e.message}"
      end
    end

    it 'returns a JSON response with the standardized error format' do
      user = create(:user, password: 'password123')
      token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]

      begin
        get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }
        expect(response.content_type).to include('application/json')
        parsed = JSON.parse(response.body)
        expect(parsed).to have_key('code')
      rescue StandardError => e
        raise "Expected a JSON 500 response, but the exception was re-raised: #{e.class}"
      end
    end
  end
end
