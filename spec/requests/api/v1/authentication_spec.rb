require 'swagger_helper'

RSpec.describe 'API V1 Authentication', type: :request do
  path '/api/v1/auth/login' do
    post 'Authentifie un utilisateur' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :login_params, in: :body, schema: { '$ref' => '#/components/schemas/login' }

      response '200', 'Authentification réussie' do
        let(:user) { User.create(email: 'test@example.com', password: 'password123', password_confirmation: 'password123') }
        let(:login_params) { { email: user.email, password: 'password123' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['email']).to eq(user.email)
        end
      end

      response '401', 'Authentification échouée' do
        let(:login_params) { { email: 'wrong@example.com', password: 'wrongpass' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('unauthorized')
        end
      end
    end
  end
end 