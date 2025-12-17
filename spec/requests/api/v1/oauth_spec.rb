# spec/requests/api/v1/oauth_spec.rb

# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'OAuth Authentication', type: :request do
  path '/api/v1/auth/{provider}/callback' do
    post 'OAuth callback for provider authentication' do
      tags 'OAuth'
      produces 'application/json'
      consumes 'application/json'

      parameter name: :provider, in: :path, type: :string, required: true,
                description: 'OAuth provider',
                schema: { type: :string, enum: ['google_oauth2', 'github'] }

      parameter name: :code, in: :body, type: :string, required: true,
                description: 'OAuth authorization code received from provider',
                schema: {
                  type: :object,
                  properties: {
                    code: { type: :string, description: 'OAuth authorization code' },
                    redirect_uri: { type: :string, format: :uri, description: 'Redirect URI used in OAuth flow' }
                  },
                  required: ['code', 'redirect_uri']
                }

      response '200', 'successful OAuth authentication' do
        let(:provider) { 'google_oauth2' }
        let(:code) { 'valid_oauth_code' }

        schema type: :object,
               properties: {
                 token: { type: :string, description: 'JWT authentication token' },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :string, format: :uuid, description: 'User unique identifier' },
                     email: { type: :string, format: :email, description: 'User email address' },
                     provider: { type: :string, description: 'OAuth provider used' },
                     provider_uid: { type: :string, description: 'User unique identifier from OAuth provider' }
                   },
                   required: %w[id email provider provider_uid]
                 }
               },
               required: %w[token user]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to include('id', 'email', 'provider', 'provider_uid')
        end
      end

      response '400', 'invalid provider' do
        let(:provider) { 'facebook' }
        let(:code) { 'valid_oauth_code' }

        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_provider', description: 'Error code' }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_provider')
        end
      end

      response '401', 'OAuth authentication failed' do
        let(:provider) { 'google_oauth2' }
        let(:code) { 'invalid_oauth_code' }

        schema type: :object,
               properties: {
                 error: { type: :string, example: 'oauth_failed', description: 'Error code' }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('oauth_failed')
        end
      end

      response '422', 'invalid payload' do
        let(:provider) { 'google_oauth2' }
        let(:code) { {}.to_json }

        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_payload', description: 'Error code' }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_payload')
        end
      end

      response '500', 'internal server error' do
        let(:provider) { 'google_oauth2' }
        let(:code) { 'valid_oauth_code' }

        # This test would require mocking JWT encoding to fail
        before do
          allow(JsonWebToken).to receive(:encode).and_raise(JWT::EncodeError.new('Invalid secret key'))
        end

        schema type: :object,
               properties: {
                 error: { type: :string, example: 'internal_error', description: 'Error code' }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('internal_error')
        end
      end
    end
  end

  path '/api/v1/auth/failure' do
    get 'OAuth failure endpoint' do
      tags 'OAuth'
      produces 'application/json'

      response '401', 'OAuth authentication failed' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'oauth_failed', description: 'Error code' },
                 message: { type: :string, example: 'OAuth authentication failed', description: 'Error message' }
               },
               required: %w[error message]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('oauth_failed')
          expect(data['message']).to be_present
        end
      end
    end
  end
end
