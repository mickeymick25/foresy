# frozen_string_literal: true

# W1-D4 — Caractérisation des branches VIVANTES de StandardizedError
# (plan : docs/technical/testing/p6_wave1_tracker.md §3 W1-D4 — arbitrage CTO 19/09)
#
# Caractérisées via chemins API réels :
#   error_unauthorized       — POST /auth/login sans email (AuthenticationController,
#                              branche `login_params[:email].blank?` jamais exercée)
#   handle_parameter_missing — POST /signup sans wrapper `user` : params.require(:user)
#     + error_missing_parameter   (UsersController#user_params lève ParameterMissing)
#
# Latents/injoignables — documentés au journal, AUCUN test artificiel (P6.0) :
#   error_invalid_enum, error_malformed_json, validate_required_params,
#   validate_enum, validate_json : zéro appelant dans app/
#   handle_unpermitted_parameters : injoignable — action_on_unpermitted_parameters
#     non configuré (= :log par défaut, l'exception n'est jamais levée)
require 'rails_helper'

RSpec.describe 'StandardizedError contract', type: :request do
  describe 'error_unauthorized — POST /api/v1/auth/login sans email' do
    it 'returns 401 with the flat error contract' do
      post '/api/v1/auth/login', params: { password: 'whatever' }

      expect(response).to have_http_status(:unauthorized)

      json = JSON.parse(response.body)
      expect(json['code']).to eq('UNAUTHORIZED')
      expect(json['message']).to eq('Email is required')
      expect(json.key?('error')).to be false
      expect(json.key?('timestamp')).to be false
    end
  end

  describe 'handle_parameter_missing / error_missing_parameter — POST /api/v1/signup sans wrapper user' do
    it 'returns 400 with MISSING_PARAMETER and the parameter detail' do
      # Paramètres « plats » volontairement (pas de JSON) : wrap_parameters ne
      # crée le wrapper :user que pour les requêtes JSON — params.require(:user)
      # lève ActionController::ParameterMissing.
      post '/api/v1/signup', params: { email: 'user@example.com', password: 'Password1!' }

      expect(response).to have_http_status(:bad_request)

      json = JSON.parse(response.body)
      expect(json['code']).to eq('MISSING_PARAMETER')
      expect(json['message']).to eq('Required parameter missing: user')
      expect(json['details']).to include('parameter' => 'user')
      expect(json.key?('error')).to be false
      expect(json.key?('timestamp')).to be false
    end
  end
end
