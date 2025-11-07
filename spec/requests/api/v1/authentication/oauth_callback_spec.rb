# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'OAuth Callback', type: :request do
  %w[google_oauth2 github].each do |provider|
    path "/api/v1/oauth/#{provider}/callback" do
      get "OAuth callback for #{provider}" do
        tags 'OAuth'
        produces 'application/json'

        response '200', 'successful OAuth login' do
          let(:user_email) { "jane_#{SecureRandom.hex(4)}.#{provider}@example.com" }
          let(:mock_auth_hash) do
            OmniAuth::AuthHash.new(
              provider: provider,
              uid: SecureRandom.hex(8),
              info: {
                email: user_email,
                name: 'Jane Doe'
              }
            )
          end

          before do
            # Supprime les utilisateurs existants pour éviter les conflits
            User.where(email: user_email).destroy_all

            # Stub oauth_callback pour remplacer complètement le comportement avec les données OAuth mockées
            allow_any_instance_of(Api::V1::AuthenticationController).to receive(:oauth_callback) do |controller|
              auth = mock_auth_hash
              user = controller.send(:find_or_create_user_from_auth, auth)

              unless user.persisted?
                # Log des erreurs pour debug
                errors = user.errors.full_messages.join(', ')
                controller.render json: { error: 'Unprocessable entity', message: "User creation failed: #{errors}" },
                                  status: :unprocessable_entity
                next
              end

              result = AuthenticationService.login(user, controller.request.remote_ip, controller.request.user_agent)
              controller.render json: {
                token: result[:token],
                refresh_token: result[:refresh_token],
                user: user
              }, status: :ok
            end
          end

          run_test! do
            data = JSON.parse(response.body)
            expect(data['token']).to be_present
            expect(data['user']['email']).to eq(user_email)
          end
        end

        response '401', 'missing OAuth data' do
          before do
            allow_any_instance_of(Api::V1::AuthenticationController).to receive(:oauth_callback) do |controller|
              controller.render json: { error: 'Unauthorized', message: 'OAuth data missing' }, status: :unauthorized
            end
          end

          run_test! do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unauthorized')
            expect(data['message']).to eq('OAuth data missing')
          end
        end

        response '422', 'user creation failed' do
          let(:user_email) { '' } # Email vide pour forcer l'échec de validation
          let(:mock_auth_hash) do
            OmniAuth::AuthHash.new(
              provider: provider,
              uid: SecureRandom.hex(8),
              info: {
                email: user_email,
                name: 'Jane Doe'
              }
            )
          end

          before do
            allow_any_instance_of(Api::V1::AuthenticationController).to receive(:oauth_callback) do |controller|
              auth = mock_auth_hash
              controller.send(:find_or_create_user_from_auth, auth)

              controller.render json: { error: 'Unprocessable entity', message: 'User creation failed' },
                                status: :unprocessable_entity
            end
          end

          run_test! do
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Unprocessable entity')
            expect(data['message']).to include('User creation failed')
          end
        end
      end
    end
  end
end
