# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Callback', type: :request do
  %w[google_oauth2 github].each do |provider|
    describe "OAuth flow with #{provider}" do
      let(:user_email) { "jane.#{provider}@example.com" }
      let(:provider_name) { provider }

      let(:mock_auth_hash) do
        OmniAuth::AuthHash.new(
          provider: provider_name,
          uid: '123456',
          info: {
            email: user_email,
            name: 'Jane Doe'
          }
        )
      end

      before(:each) do
        User.find_by(email: user_email)&.destroy
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[provider_name.to_sym] = mock_auth_hash
        # Stub directement request.env['omniauth.auth'] pour les tests d'intégration
        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = mock_auth_hash
          env
        end
      end

      after(:each) do
        OmniAuth.config.mock_auth[provider_name.to_sym] = nil
        OmniAuth.config.test_mode = false
        # Nettoie la simulation omniauth.auth
        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_call_original
      end

      shared_examples 'a successful OAuth login' do
        it 'returns a JWT token and user info' do
          subject
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json).to include('token')
          expect(json['user']['email']).to eq(user_email)
        end
      end

      describe 'GET /api/v1/oauth/:provider/callback' do
        subject { get "/api/v1/oauth/#{provider_name}/callback" }

        before do
          OmniAuth.config.mock_auth[provider_name.to_sym] = mock_auth_hash
        end

        it_behaves_like 'a successful OAuth login'

        context 'when user already exists' do
          let!(:existing_user) do
            User.create!(email: user_email, name: 'Jane Doe', provider: provider_name, uid: '123456')
          end

          it 'returns a token for the existing user without creating a new one' do
            expect { subject }.not_to change(User, :count)

            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['user']['email']).to eq(existing_user.email)
            expect(json['token']).to be_present
          end

          it 'does not overwrite the existing user name with the provider name' do
            modified_auth_hash = OmniAuth::AuthHash.new(
              provider: provider_name,
              uid: '123456',
              info: {
                email: user_email,
                name: 'OAuth Provider Name'
              }
            )

            OmniAuth.config.mock_auth[provider_name.to_sym] = modified_auth_hash

            subject

            existing_user.reload
            expect(existing_user.name).to eq('Jane Doe') # No overwrite
          end
        end

        context 'when omniauth.auth is missing' do
          before do
            allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
              env = m.call(*args)
              env['omniauth.auth'] = nil
              env
            end
          end

          it 'returns an unauthorized error' do
            subject

            expect(response).to have_http_status(:unauthorized)
            json = JSON.parse(response.body)
            expect(json['error']).to eq('OAuth data missing')
          end
        end

        context 'when user creation fails' do
          before do
            # Force un échec de création en fournissant un email vide
            bad_auth = mock_auth_hash.deep_dup
            bad_auth[:info][:email] = ''
            allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
              env = m.call(*args)
              env['omniauth.auth'] = bad_auth
              env
            end
          end

          it 'returns a 422 Unprocessable Entity' do
            subject

            expect(response).to have_http_status(:unprocessable_entity)
            json = JSON.parse(response.body)
            expect(json['error']).to eq('User creation failed')
          end
        end
      end
    end
  end
end
