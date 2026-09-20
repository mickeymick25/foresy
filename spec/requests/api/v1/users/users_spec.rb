# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Users', type: :request do
  before do
    # Stub RateLimitServices for auth tests (FC-05 specs test real behavior)
    # NOTE: allowed? doesn't exist, only check_rate_limit is available
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
    RateLimitService.clear_rate_limit('auth/signup', '127.0.0.1')
  end

  describe 'POST /api/v1/signup with flat JSON params (Postman-compatible)' do
    it 'accepts flat JSON body and creates a user' do
      email = "flat_#{SecureRandom.hex(4)}@example.com"
      post '/api/v1/signup',
           params: { email: email, password: 'password123',
                     password_confirmation: 'password123' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data['token']).to be_present
      expect(data['email']).to be_present
    end
  end

  path '/api/v1/signup' do
    post 'Crée un nouvel utilisateur' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user_params, in: :body, required: true, schema: { '$ref' => '#/components/schemas/user' }

      response '201', 'Utilisateur créé' do
        let(:user_params) do
          {
            user: {
              email: "user_#{SecureRandom.hex(4)}@example.com",
              password: 'password123',
              password_confirmation: 'password123'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['email']).to eq(user_params[:user][:email])
        end
      end

      response '422', 'Création échouée' do
        let(:user_params) do
          {
            email: 'invalid',
            password: 'short',
            password_confirmation: 'different'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['code']).to eq('INVALID_PAYLOAD')
          expect(data['message']).to be_a(String)
          expect(data['message']).not_to be_empty
          expect(data['details']['errors']).to be_an(Array)
          expect(data['details']['errors']).to be_an(Array)
          expect(data['details']['errors']).not_to be_empty
          expect(data.key?('error')).to be false
        end
      end
    end
  end

  # D-8 — contrat 2026_08_18_error_contract.md : ParameterMissing → 400 MISSING_PARAMETER
  # (le handler StandardError ne doit pas avaler les exceptions spécifiques)
  describe 'POST /api/v1/signup with empty payload (ParameterMissing contract)' do
    before { RateLimitService.clear_rate_limit('auth/signup', '127.0.0.1') }

    it 'returns 400 MISSING_PARAMETER with the standardized flat error shape' do
      post '/api/v1/signup', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('MISSING_PARAMETER')
      expect(data['message']).to be_present
      expect(data.key?('error')).to be false
    end
  end
end
