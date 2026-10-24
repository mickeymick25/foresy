# frozen_string_literal: true

require 'rails_helper'

# W2-D2 — Caractérisation unitaire de OAuthCodeExchangeService (P6 Wave 2)
#
# Règle de campagne (P6.0 / tracker p6_wave2 §1) : caractérisation du comportement EXISTANT ;
# stub Net::HTTP UNIQUEMENT (aucun stub des services applicatifs aval) ; aucun appel réseau réel.
# Les 9 chemins documentés au tracker §3.2 + la configuration réseau sont caractérisés tels quels.
#
# Mécanique de stub :
# - Google token : Net::HTTP.post_form (ne passe PAS par perform_https_request)
# - GitHub token + tous les GET : perform_https_request → Net::HTTP#request
#   (use_ssl: true, timeouts 10 s — caractérisés)
# - Les réponses stubbées sont de VRAIES instances Net::HTTP* (parse_json_response
#   teste response.is_a?(Net::HTTPSuccess))
RSpec.describe OAuthCodeExchangeService do
  def http_ok(body)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return(body) # body= hors bloc de lecture → IOError au read
    response
  end

  def http_error(code, message, body)
    response = Net::HTTPServerError.new('1.1', code, message)
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

  describe 'provider non supporté' do
    it 'lève ExchangeError "Unsupported provider: <provider>"' do
      expect do
        described_class.exchange(provider: 'facebook', code: 'c', redirect_uri: 'https://cb')
      end.to raise_error(described_class::ExchangeError, 'Unsupported provider: facebook')
    end
  end

  describe 'Google' do
    it 'caractérise l échange complet : token POST form + userinfo GET Bearer → AuthHash' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'access_token' => 'g-token' }.to_json)
      )
      net_http_double(http_ok(
                        { 'id' => 42, 'email' => 'user@google.com', 'name' => 'Google User',
                          'picture' => 'https://img' }.to_json
                      ))

      auth = described_class.exchange(provider: 'google_oauth2', code: 'code-1',
                                      redirect_uri: 'https://client.app/callback')

      expect(Net::HTTP).to have_received(:post_form).with(
        URI('https://oauth2.googleapis.com/token'),
        hash_including(code: 'code-1', redirect_uri: 'https://client.app/callback',
                       grant_type: 'authorization_code')
      )
      expect(auth).to be_a(OmniAuth::AuthHash)
      expect(auth.provider).to eq('google_oauth2')
      expect(auth.uid).to eq(42) # asymétrie vs GitHub : uid Google NON stringifié
      expect(auth.info.email).to eq('user@google.com')
      expect(auth.info.name).to eq('Google User')
      expect(auth.info.image).to eq('https://img')
      expect(auth.info.nickname).to be_nil
    end

    it 'lève ExchangeError quand la réponse token ne contient pas access_token' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'error' => 'invalid_grant' }.to_json)
      )

      expect do
        described_class.exchange(provider: 'google_oauth2', code: 'c', redirect_uri: 'https://cb')
      end.to raise_error(described_class::ExchangeError, 'Failed to obtain Google access token')
    end
  end

  describe 'GitHub' do
    it 'caractérise l échange complet : token + /user avec email présent (uid stringifié)' do
      http_double = net_http_double(
        http_ok({ 'access_token' => 'gh-token' }.to_json),
        http_ok({ 'id' => 777, 'login' => 'ghuser', 'email' => 'dev@github.com',
                  'name' => 'GH User', 'avatar_url' => 'https://a' }.to_json)
      )

      auth = described_class.exchange(provider: 'github', code: 'code-2',
                                      redirect_uri: 'https://client.app/callback')

      expect(auth).to be_a(OmniAuth::AuthHash)
      expect(auth.provider).to eq('github')
      expect(auth.uid).to eq('777') # asymétrie vs Google : uid GitHub en to_s
      expect(auth.info.email).to eq('dev@github.com')
      expect(auth.info.name).to eq('GH User')
      expect(auth.info.nickname).to eq('ghuser')
      expect(auth.info.image).to eq('https://a')
      expect(http_double).to have_received(:request).twice # token + /user, PAS /user/emails
    end

    it 'utilise le fallback /user/emails (primary && verified) quand /user ne donne pas d email' do
      net_http_double(
        http_ok({ 'access_token' => 'gh-token' }.to_json),
        http_ok({ 'id' => 777, 'login' => 'ghuser', 'email' => nil }.to_json),
        http_ok([{ 'email' => 'other@x.com', 'primary' => false, 'verified' => true },
                 { 'email' => 'primary@x.com', 'primary' => true, 'verified' => true }].to_json)
      )

      auth = described_class.exchange(provider: 'github', code: 'code-3',
                                      redirect_uri: 'https://client.app/callback')

      expect(auth.uid).to eq('777')
      expect(auth.info.email).to eq('primary@x.com')
    end

    it 'lève ExchangeError quand aucun email primary && verified n est disponible' do
      net_http_double(
        http_ok({ 'access_token' => 'gh-token' }.to_json),
        http_ok({ 'id' => 777, 'login' => 'ghuser', 'email' => nil }.to_json),
        http_ok([{ 'email' => 'unverified@x.com', 'primary' => true, 'verified' => false }].to_json)
      )

      expect do
        described_class.exchange(provider: 'github', code: 'c', redirect_uri: 'https://cb')
      end.to raise_error(described_class::ExchangeError, 'GitHub account has no public email')
    end

    it 'lève ExchangeError avec error_description quand le token GitHub est vide' do
      net_http_double(http_ok(
                        { 'error' => 'bad_verification_code',
                          'error_description' => 'The code has expired' }.to_json
                      ))

      expect do
        described_class.exchange(provider: 'github', code: 'c', redirect_uri: 'https://cb')
      end.to raise_error(
        described_class::ExchangeError,
        'Failed to obtain GitHub access token: The code has expired'
      )
    end
  end

  describe 'parse_json_response (toutes les requêtes)' do
    it 'lève ExchangeError et log l échec sur une réponse HTTP non-success' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'access_token' => 'g-token' }.to_json)
      )
      net_http_double(http_error('401', 'Unauthorized', '{"error":"expired"}'))
      allow(Rails.logger).to receive(:error)

      expect do
        described_class.exchange(provider: 'google_oauth2', code: 'c', redirect_uri: 'https://cb')
      end.to raise_error(described_class::ExchangeError, 'Google user info failed with status 401')

      expect(Rails.logger).to have_received(:error)
        .with(a_string_matching(/Google user info failed: 401 - \{"error"/))
    end

    it 'lève ExchangeError et log le contexte sur un JSON invalide' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'access_token' => 'g-token' }.to_json)
      )
      net_http_double(http_ok('not-json'))
      allow(Rails.logger).to receive(:error)

      expect do
        described_class.exchange(provider: 'google_oauth2', code: 'c', redirect_uri: 'https://cb')
      end.to raise_error(described_class::ExchangeError, 'Google user info returned invalid JSON')

      expect(Rails.logger).to have_received(:error)
        .with(a_string_matching(/Google user info JSON parse error:/))
    end
  end

  describe 'configuration réseau (perform_https_request)' do
    it 'caractérise use_ssl=true et les timeouts à 10 secondes' do
      allow(Net::HTTP).to receive(:post_form).and_return(
        http_ok({ 'access_token' => 'g-token' }.to_json)
      )
      http_double = net_http_double(http_ok({ 'id' => 42 }.to_json))

      described_class.exchange(provider: 'google_oauth2', code: 'c', redirect_uri: 'https://cb')

      expect(http_double).to have_received(:use_ssl=).with(true)
      expect(http_double).to have_received(:open_timeout=).with(10)
      expect(http_double).to have_received(:read_timeout=).with(10)
    end
  end
end
