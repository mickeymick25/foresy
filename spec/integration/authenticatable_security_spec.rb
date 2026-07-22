# frozen_string_literal: true

# 🔒 Security invariant spec: JWT tokens must NEVER be logged to stdout.
#
# This spec characterizes the security fix for audit point C3
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The Authenticatable concern had 7 `puts` statements in
# authenticate_access_token!, including one that printed the full
# Authorization header (the Bearer JWT token) to stdout.
#
# Invariant: After an authenticated request, stdout must NOT contain
# the JWT token or any part of it.

require 'rails_helper'

RSpec.describe 'JWT token non-disclosure in stdout', type: :request do
  let(:user) { create(:user, email: 'security@example.com', password: 'password123') }

  describe 'authenticated request via Authenticatable concern' do
    it 'does not leak the JWT token to stdout' do
      token = token_for(user)

      stdout_capture = StringIO.new
      original_stdout = $stdout
      $stdout = stdout_capture

      begin
        get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }
      ensure
        $stdout = original_stdout
      end

      output = stdout_capture.string
      expect(output).not_to include(token)
      expect(output).not_to include(token[0..20])
    end

    it 'does not print the Authorization header to stdout' do
      token = token_for(user)

      stdout_capture = StringIO.new
      original_stdout = $stdout
      $stdout = stdout_capture

      begin
        get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }
      ensure
        $stdout = original_stdout
      end

      output = stdout_capture.string
      expect(output).not_to match(/Authorization/i)
      expect(output).not_to match(/Bearer\s/i)
    end

    it 'does not print debug output from authenticate_access_token!' do
      token = token_for(user)

      stdout_capture = StringIO.new
      original_stdout = $stdout
      $stdout = stdout_capture

      begin
        get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }
      ensure
        $stdout = original_stdout
      end

      output = stdout_capture.string
      expect(output).not_to include('=== DEBUG: authenticate_access_token! ===')
      expect(output).not_to include('token present?')
      expect(output).not_to include('current_user.id')
    end
  end
end
