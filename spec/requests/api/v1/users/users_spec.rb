# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Users', type: :request do
  before do
    # Stub RateLimitService for auth tests (FC-05 specs test real behavior)
    # NOTE: allowed? doesn't exist, only check_rate_limit is available
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
    RateLimitService.clear_rate_limit('auth/signup', '127.0.0.1')
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
          expect(data['error']).to eq('Validation Failed')
          expect(data['message']).to be_an(Array)
          expect(data['message']).not_to be_empty
        end
      end
    end
  end
end
