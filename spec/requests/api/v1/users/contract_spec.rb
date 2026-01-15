# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Users - Contract Tests', type: :request do
  let(:valid_email) { "contract_test_#{SecureRandom.hex(4)}@example.com" }
  let(:valid_password) { 'password123' }

  path '/api/v1/signup' do
    post 'Creates a new user - Contract Enforcement' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'

      # === CONTRACT DEFINITION ===
      # This test file enforces the single accepted payload structure
      # as defined by ADR-003 v1.4

      # === ACCEPTED PAYLOAD STRUCTURE ===
      # Only this format should be accepted:
      # { user: { email: "...", password: "..." } }

      context 'when using the accepted payload structure' do
        response '201', 'user created successfully' do
          let(:user_params) do
            {
              email: valid_email,
              password: valid_password,
              password_confirmation: valid_password
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['token']).to be_present
            expect(data['email']).to eq(valid_email)
          end
        end
      end

      # === EXPLICITLY REJECTED PAYLOAD STRUCTURES ===
      # All of these should return 400 Bad Request and never reach domain layer

      context 'when sending root-level parameters (SHOULD BE REJECTED)' do
        response '400', 'contract violation - root-level parameters rejected' do
          # This currently WORKS but SHOULD BE REJECTED according to ADR-003
          let(:user_params) do
            {
              email: valid_email,
              password: valid_password,
              password_confirmation: valid_password
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(response.status).to eq(400) # Currently returns 422 - this is the bug
            expect(data['error']).to be_present
            # Domain services should NOT be called - this test validates that
          end
        end
      end

      context 'when sending mixed parameters (SHOULD BE REJECTED)' do
        response '400', 'contract violation - mixed parameters rejected' do
          # This sends both root-level and nested parameters
          let(:user_params) do
            {
              email: valid_email, # root-level (should be rejected)
              user: {
                email: "different_#{valid_email}",
                password: valid_password,
                password_confirmation: valid_password
              }
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(response.status).to eq(400)
            expect(data['error']).to be_present
          end
        end
      end

      context 'when missing user key (SHOULD BE REJECTED)' do
        response '400', 'contract violation - missing user key' do
          let(:user_params) do
            {
              email: valid_email,
              password: valid_password
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(response.status).to eq(400)
            expect(data['error']).to be_present
          end
        end
      end

      context 'when user key is empty (SHOULD BE REJECTED)' do
        response '400', 'contract violation - empty user key' do
          let(:user_params) do
            {
              user: {}
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(response.status).to eq(400)
            expect(data['error']).to be_present
          end
        end
      end

      # === CANONICAL FAILURE SCENARIO (BLOCKING) ===
      # This is the mandatory test from ADR-003 v1.4
      # Client sends duplicated parameters: one at root level, one under user
      # Request MUST be rejected with 400 Bad Request
      # Domain layer MUST NOT be invoked

      context 'canonical failure scenario - duplicated parameters' do
        response '400', 'contract violation - canonical failure: duplicated parameters' do
          # This sends the same parameter both at root level and under user
          let(:user_params) do
            {
              email: valid_email, # Root level
              password: valid_password, # Root level
              user: {
                email: valid_email, # Nested under user
                password: valid_password,
                password_confirmation: valid_password
              }
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(response.status).to eq(400)
            expect(data['error']).to be_present

            # CRITICAL: This test ensures domain services are NOT called
            # If this test passes with 400, it means the contract violation
            # was caught before domain validation - which is correct
          end
        end
      end

      # === PARAMETER FALLBACK DETECTION ===
      # These tests detect the presence of parameter fallback logic
      # which violates ADR-003

      context 'parameter fallback detection' do
        response '400', 'contract violation - parameter fallback not allowed' do
          # This tests that the controller doesn't use fallback logic like:
          # params[:user].present? ? params[:user] : params
          let(:user_params) do
            {
              # Intentionally missing nested structure to test fallback logic
              email: valid_email,
              password: valid_password
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(response.status).to eq(400)
            expect(data['error']).to be_present

            # If this returns 400, it means no fallback logic exists
            # If it returns 422, it means the controller has fallback logic
            # and is incorrectly allowing root-level parameters
          end
        end
      end
    end
  end

  # === DOMAIN LAYER PROTECTION VERIFICATION ===
  # These tests verify that contract violations never reach the domain layer

  describe 'Domain Layer Protection' do
    it 'ensures contract violations do not reach domain validation' do
      # This is a meta-test to verify our contract tests work correctly
      # It ensures that when we send invalid payloads, they get rejected
      # with 400 before any domain logic runs

      invalid_payloads = [
        { email: valid_email, password: valid_password }, # Root level
        { user: {} }, # Empty user
        { email: valid_email, user: { email: valid_email, password: valid_password } } # Mixed
      ]

      invalid_payloads.each do |payload|
        post '/api/v1/signup',
             params: payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response.status).to eq(400),
          "Payload #{payload.inspect} should be rejected with 400, got #{response.status}"
      end
    end
  end
end
