# frozen_string_literal: true

require 'rails_helper'

# W2-D3 — Caractérisation intégrée du flow code-exchange (P6 Wave 2)
#
# POST /api/v1/auth/:provider/callback de bout en bout :
# stub Net::HTTP UNIQUEMENT — aucun stub de OAuthValidationService, OAuthUserService
# ou OAuthTokenService : utilisateur réellement créé/lié en base, JWT réellement généré
# (payload {user_id, provider, exp} — OAuthTokenService, expiration 15 min).
#
# Pattern RateLimitService repris des specs auth existantes (oauth_spec.rb).
# Helpers de stub : mêmes mécaniques que W2-D2 (vraies instances Net::HTTP*, lecteur body stubbé).
RSpec.describe 'API V1 OAuth code-exchange', type: :request do
  before do
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  def http_ok(body)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return(body)
    response
  end

  def net_http_double(*responses)
    dbl = instance_double(Net::HTTP)
    allow(dbl).to receive(:use_ssl=)
    allow(dbl).to receive(:open_timeout=)
    allow(dbl).to receive(:read_timeout=)
    allow(dbl).to receive(:request).and_return(*responses)
    allow(Net::HTTP).to receive(:new).and_return(dbl)
    dbl
  end

  def post_callback(provider, body)
    post "/api/v1/auth/#{provider}/callback", params: body, as: :json
  end

  describe 'succès — Google (flow réel, utilisateur créé + JWT réel)' do
    it 'retourne 200 avec token + payload utilisateur, et crée l utilisateur en base' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'access_token' => 'g-token' }.to_json)
      )
      net_http_double(http_ok(
                        { 'id' => 42_001, 'email' => 'google.user@foresy.dev', 'name' => 'Google User',
                          'picture' => 'https://img' }.to_json
                      ))

      post_callback('google_oauth2', code: 'google-code',
                                     redirect_uri: 'https://client.app/callback')

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      user = User.find_by(provider: 'google_oauth2', uid: '42001')
      expect(user).to be_present
      expect(user.email).to eq('google.user@foresy.dev')
      expect(user.name).to eq('Google User')
      expect(user.active).to be(true)

      expect(data['token']).to be_present
      expect(data['user']).to include('id' => user.id, 'email' => 'google.user@foresy.dev',
                                      'name' => 'Google User', 'provider' => 'google_oauth2')
      expect(data['user']['provider_uid'].to_s).to eq('42001')

      payload = JsonWebToken.decode(data['token'])
      expect(payload['user_id']).to eq(user.id)
      expect(payload['provider']).to eq('google_oauth2')
      expect(payload['exp']).to be_present
    end
  end

  describe 'succès — GitHub (fallback /user/emails, utilisateur lié puis créé)' do
    it 'retourne 200 avec token + payload utilisateur, et crée l utilisateur en base' do
      net_http_double(
        http_ok({ 'access_token' => 'gh-token' }.to_json),
        http_ok({ 'id' => 77_002, 'login' => 'foresy-gh', 'email' => nil }.to_json),
        http_ok([{ 'email' => 'other@x.com', 'primary' => false, 'verified' => true },
                 { 'email' => 'gh.user@foresy.dev', 'primary' => true,
                   'verified' => true }].to_json)
      )

      post_callback('github', code: 'github-code', redirect_uri: 'https://client.app/callback')

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      user = User.find_by(provider: 'github', uid: '77002')
      expect(user).to be_present
      expect(user.email).to eq('gh.user@foresy.dev') # primary && verified du fallback
      expect(user.name).to eq('foresy-gh') # name absent → login (extract_user_name)

      expect(data['token']).to be_present
      expect(data['user']).to include('id' => user.id, 'email' => 'gh.user@foresy.dev',
                                      'provider' => 'github')
      expect(data['user']['provider_uid'].to_s).to eq('77002')

      payload = JsonWebToken.decode(data['token'])
      expect(payload['user_id']).to eq(user.id)
      expect(payload['provider']).to eq('github')
    end
  end

  describe 'échec échange → 401 (ExchangeError avalé → oauth_failed)' do
    it 'retourne 401 UNAUTHORIZED quand le token Google ne contient pas access_token' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'error' => 'invalid_grant' }.to_json)
      )

      post_callback('google_oauth2', code: 'invalid-code',
                                     redirect_uri: 'https://client.app/callback')

      expect(response).to have_http_status(:unauthorized)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('UNAUTHORIZED')
      expect(data['message']).to eq('OAuth authentication failed')
      expect(data.key?('error')).to be false
      expect(User.find_by(provider: 'google_oauth2', uid: '42001')).to be_nil
    end
  end

  describe 'payload incomplet' do
    it 'retourne 422 INVALID_PAYLOAD quand le code est absent' do
      post_callback('google_oauth2', redirect_uri: 'https://client.app/callback')

      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('INVALID_PAYLOAD')
      expect(data['message']).to eq('Invalid OAuth payload')
    end

    it 'retourne 422 INVALID_PAYLOAD quand le redirect_uri est absent' do
      post_callback('google_oauth2', code: 'auth-code')

      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('INVALID_PAYLOAD')
      expect(data['message']).to eq('Invalid OAuth payload')
    end

    it 'retourne 422 INVALID_PAYLOAD quand les données échangées sont incomplètes (email absent)' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'access_token' => 'g-token' }.to_json)
      )
      net_http_double(http_ok({ 'id' => 42_003, 'email' => nil, 'name' => 'No Email' }.to_json))

      post_callback('google_oauth2', code: 'google-code',
                                     redirect_uri: 'https://client.app/callback')

      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('INVALID_PAYLOAD')
      expect(data['message']).to eq('Invalid OAuth payload')
      expect(User.find_by(provider: 'google_oauth2', uid: '42003')).to be_nil
    end
  end

  describe 'provider invalide' do
    it 'retourne 400 BAD_REQUEST pour un provider non supporté' do
      post_callback('facebook', code: 'auth-code', redirect_uri: 'https://client.app/callback')

      expect(response).to have_http_status(:bad_request)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('BAD_REQUEST')
      expect(data['message']).to eq('Invalid OAuth provider')
      expect(data.key?('error')).to be false
    end
  end
end
