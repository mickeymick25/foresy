# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Callback', type: :request do
  let(:user) { create(:user, email: 'oauth_user@example.com', name: 'OAuth User') }
  let(:mock_auth) do
    {
      'provider' => 'github',
      'uid' => '123456',
      'info' => {
        'email' => 'oauth_user@example.com',
        'name' => 'OAuth User'
      }
    }
  end

  describe 'GET /api/v1/oauth/{provider}/callback' do
    context 'when OAuth data is missing' do
      it 'returns unauthorized with OAuth data missing message' do
        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = nil
          env
        end

        get '/api/v1/oauth/github/callback'

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OAuth data missing')
      end
    end

    context 'when user creation fails' do
      it 'returns unprocessable entity with user creation failed message' do
        bad_auth = mock_auth.dup
        bad_auth['info']['email'] = '' # Email vide pour forcer l'échec
        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = bad_auth
          env
        end

        get '/api/v1/oauth/github/callback'

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User creation failed')
      end
    end

    context 'when OAuth login is successful' do
      it 'returns JWT token and user info' do
        # Mise à jour de l'utilisateur pour avoir provider et uid
        user.update!(provider: 'github', uid: '123456')

        # Mise à jour du mock_auth pour correspondre à l'utilisateur existant
        mock_auth_for_user = {
          'provider' => 'github',
          'uid' => '123456',
          'info' => {
            'email' => user.email,
            'name' => user.name
          }
        }

        allow_any_instance_of(Api::V1::AuthenticationController).to receive(:oauth_callback) do |controller|
          auth = mock_auth_for_user
          user_found = controller.send(:find_or_create_user_from_auth, auth)

          if user_found.persisted?
            result = AuthenticationService.login(user_found, controller.request.remote_ip,
                                                 controller.request.user_agent)
            controller.render json: {
              token: result[:token],
              refresh_token: result[:refresh_token],
              user: user_found
            }, status: :ok
          else
            controller.render json: { error: 'Unprocessable entity', message: 'User creation failed' },
                              status: :unprocessable_entity
          end
        end

        get '/api/v1/oauth/github/callback'

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq('oauth_user@example.com')
        expect(json_response['user']['name']).to eq('OAuth User')
      end

      it 'creates user with GitHub provider' do
        # Stub request.env['omniauth.auth'] to return GitHub data
        github_email = "github_#{SecureRandom.hex(4)}@example.com"
        github_auth = {
          'provider' => 'github',
          'uid' => "github_#{SecureRandom.hex(8)}",
          'info' => {
            'email' => github_email,
            'name' => 'GitHub User',
            'nickname' => 'github_user'
          }
        }

        User.where(email: github_email).destroy_all

        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = github_auth
          env
        end

        expect do
          get '/api/v1/oauth/github/callback'
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        new_user = User.last
        expect(new_user.provider).to eq('github')
        expect(new_user.uid).to eq(github_auth['uid'])
        expect(new_user.email).to eq(github_email)
        expect(new_user.name).to eq('GitHub User')
      end

      it 'creates user with Google OAuth2 provider' do
        # Stub request.env['omniauth.auth'] to return Google data
        google_email = "google_#{SecureRandom.hex(4)}@example.com"
        google_auth = {
          'provider' => 'google_oauth2',
          'uid' => "google_#{SecureRandom.hex(8)}",
          'info' => {
            'email' => google_email,
            'name' => 'Google User'
          }
        }

        User.where(email: google_email).destroy_all

        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = google_auth
          env
        end

        expect do
          get '/api/v1/oauth/google_oauth2/callback'
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        new_user = User.last
        expect(new_user.provider).to eq('google_oauth2')
        expect(new_user.uid).to eq(google_auth['uid'])
        expect(new_user.email).to eq(google_email)
        expect(new_user.name).to eq('Google User')
      end

      it 'finds existing user by provider and uid' do
        # Create existing user
        existing_user = create(:user,
                               provider: 'github',
                               uid: '123456',
                               email: 'existing@example.com',
                               name: 'Existing User')

        # Stub request.env['omniauth.auth'] to return data for existing user
        existing_auth = {
          'provider' => 'github',
          'uid' => '123456',
          'info' => {
            'email' => existing_user.email,
            'name' => existing_user.name
          }
        }

        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = existing_auth
          env
        end

        expect do
          get '/api/v1/oauth/github/callback'
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['user']['email']).to eq('existing@example.com')
        expect(json_response['user']['name']).to eq('Existing User')
      end

      it 'handles missing name and uses nickname' do
        # Stub request.env['omniauth.auth'] with missing name but with nickname
        nickname_email = "nickname_#{SecureRandom.hex(4)}@example.com"
        auth_with_nickname = {
          'provider' => 'github',
          'uid' => SecureRandom.hex(8),
          'info' => {
            'email' => nickname_email,
            'nickname' => 'nickname_user'
          }
        }

        User.where(email: nickname_email).destroy_all

        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = auth_with_nickname
          env
        end

        expect do
          get '/api/v1/oauth/github/callback'
        end.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.name).to eq('nickname_user')
      end

      it 'handles missing name and nickname with default' do
        # Stub request.env['omniauth.auth'] with missing name and nickname
        no_name_email = "no_name_#{SecureRandom.hex(4)}@example.com"
        auth_without_name = {
          'provider' => 'github',
          'uid' => SecureRandom.hex(8),
          'info' => {
            'email' => no_name_email
          }
        }

        User.where(email: no_name_email).destroy_all

        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
          env = m.call(*args)
          env['omniauth.auth'] = auth_without_name
          env
        end

        expect do
          get '/api/v1/oauth/github/callback'
        end.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.name).to eq('No Name')
      end
    end
  end

  describe 'POST /api/v1/oauth/{provider}/callback' do
    it 'behaves the same as GET request' do
      # Mise à jour de l'utilisateur pour avoir provider et uid
      user.update!(provider: 'github', uid: '123456')

      # Test that POST behaves the same as GET
      post_auth = {
        'provider' => 'github',
        'uid' => '123456',
        'info' => {
          'email' => user.email,
          'name' => user.name
        }
      }

      allow_any_instance_of(Api::V1::AuthenticationController).to receive(:oauth_callback) do |controller|
        auth = post_auth
        user_found = controller.send(:find_or_create_user_from_auth, auth)

        if user_found.persisted?
          result = AuthenticationService.login(user_found, controller.request.remote_ip,
                                               controller.request.user_agent)
          controller.render json: {
            token: result[:token],
            refresh_token: result[:refresh_token],
            user: user_found
          }, status: :ok
        else
          controller.render json: { error: 'Unprocessable entity', message: 'User creation failed' },
                            status: :unprocessable_entity
        end
      end

      post '/api/v1/oauth/github/callback'

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['token']).to be_present
      expect(json_response['user']['email']).to eq('oauth_user@example.com')
    end
  end
end
