# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'swagger_helper'

RSpec.describe 'API V1 Users', type: :request do
  path '/api/v1/signup' do
    post 'Crée un nouvel utilisateur' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user_params, in: :body, required: true, schema: { '$ref' => '#/components/schemas/user' }

      response '201', 'Utilisateur créé' do
        let(:user_params) do
          {
            email: 'test@example.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['email']).to eq('test@example.com')
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
          expect(data['errors']).to be_present
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
