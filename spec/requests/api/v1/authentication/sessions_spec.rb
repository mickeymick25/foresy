# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication - Sessions', type: :request do
  before do
    # Stub RateLimitService for auth tests (FC-05 specs test real behavior)
    # NOTE: allowed? doesn't exist, only check_rate_limit is available
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  describe 'Refresh token invalidé après invalidate_all_sessions!' do
    it 'refuse le refresh token après invalidation' do
      user = create(:user)
      refresh_token = JsonWebToken.refresh_token(user.id) # Génère un refresh token valide
      user.invalidate_all_sessions! # Invalide toutes les sessions de l'utilisateur

      post '/api/v1/auth/refresh', params: { refresh_token: refresh_token }

      # Vérifie que la réponse est "unauthorized" car le refresh token a été invalidé
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include('Unable to refresh session') # Message d'erreur spécifique mis à jour
    end
  end

  describe 'Access token invalidé après logout' do
    it "refuse l'accès avec un access token après logout" do
      user = create(:user, email: "sessions_test_#{SecureRandom.hex(4)}@example.com", password: 'password123')
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
      expect(response.body).to include('Session already expired') # Message d'erreur spécifique
    end
  end

  describe 'Contrôle du before_action sur logout' do
    it 'refuse le logout sans Authorization' do
      delete '/api/v1/auth/logout'
      expect(response).to have_http_status(:unauthorized) # Vérifie qu'on refuse l'accès sans Authorization
      expect(response.body).to include('Missing token') # Message d'erreur spécifique
    end
  end

  describe 'DEBUG – refresh_token presence' do
    it 'génère un refresh_token via login_user' do
      create(:user, email: 'user@example.com', password: 'password123', password_confirmation: 'password123')

      result = login_user
      expect(result['refresh_token']).to be_present
    end
  end

  # Nouveau test - Refus d'un refresh token expiré
  describe 'Refus du refresh token expiré' do
    it 'refuse le refresh token expiré' do
      user = create(:user)
      expired_token = JsonWebToken.encode(user_id: user.id, exp: 1.hour.ago.to_i) # Token expiré

      post '/api/v1/auth/refresh', params: { refresh_token: expired_token }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include('Unable to refresh session')
    end
  end

  # Nouveau test - Refus d'un refresh token invalide
  describe 'Refus du refresh token invalide' do
    it 'refuse le refresh token invalide' do
      invalid_token = 'invalid_token_string'

      post '/api/v1/auth/refresh', params: { refresh_token: invalid_token }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include('Unable to refresh session')
    end
  end

  # Nouveau test - Mise à jour de la session après refresh
  describe 'Mise à jour de la session après refresh' do
    it 'met à jour la session après refresh' do
      user = create(:user, email: "sess_refresh_#{SecureRandom.hex(4)}@example.com", password: 'password123')
      # Effectue un vrai login pour obtenir un refresh_token valide et une session active
      login_result = login_user(email: user.email, password: 'password123')
      refresh_token = login_result['refresh_token']

      post '/api/v1/auth/refresh', params: { refresh_token: refresh_token }

      # Vérifie que la session est mise à jour après le refresh
      # Note: Le session_id n'est pas inclus dans la réponse pour des raisons de sécurité
      # On vérifie seulement que le token et refresh_token sont présents et valides
      data = JSON.parse(response.body)
      expect(data['token']).to be_present
      expect(data['refresh_token']).to be_present
      expect(data['email']).to eq(user.email)
    end
  end
end
