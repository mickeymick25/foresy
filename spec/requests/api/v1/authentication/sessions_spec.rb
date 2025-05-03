# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'rails_helper'

RSpec.describe 'Authentication - Sessions', type: :request do
  describe 'Refresh token invalidé après invalidate_all_sessions!' do
    it 'refuse le refresh token après invalidation' do
      user = create(:user)
      refresh_token = JsonWebToken.refresh_token(user.id) # Génère un refresh token valide
      user.invalidate_all_sessions! # Invalide toutes les sessions de l'utilisateur

      post '/api/v1/auth/refresh', params: { refresh_token: refresh_token }

      # Vérifie que la réponse est "unauthorized" car le refresh token a été invalidé
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Access token invalidé après logout' do
    it "refuse l'accès avec un access token après logout" do
      user = create(:user, email: 'test@example.com', password: 'password123')
      auth = { email: user.email, password: 'password123' }

      # Connexion de l'utilisateur pour obtenir un access token
      post '/api/v1/auth/login', params: auth
      token = JSON.parse(response.body)['token']

      # Effectuer un logout avec l'access token
      delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      # Réessayer de se déconnecter avec un access token déjà invalidé
      delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized) # Devrait échouer, car le token est invalidé
    end
  end

  describe 'Contrôle du before_action sur logout' do
    it 'refuse le logout sans Authorization' do
      delete '/api/v1/auth/logout'
      expect(response).to have_http_status(:unauthorized) # Vérifie qu'on refuse l'accès sans Authorization
    end
  end

  describe 'DEBUG – refresh_token presence' do
    it 'génère un refresh_token via login_user' do
      create(:user, email: 'user@example.com', password: 'password123', password_confirmation: 'password123')

      result = login_user
      RSpec.configuration.output_stream.puts "REFRESH TOKEN: #{result['refresh_token']}"
      expect(result['refresh_token']).to be_present
    end
  end
end
# rubocop:enable Metrics/BlockLength
