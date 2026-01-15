# frozen_string_literal: true

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

      response '400', 'Contract violation - root-level parameters rejected' do
        let(:user_params) do
          {
            email: 'invalid',
            password: 'short',
            password_confirmation: 'different'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Bad Request')
          expect(data['message']).to be_present
        end
      end
    end
  end
end
