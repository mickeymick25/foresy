# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

# Contrat de signature JWT — BACKLOG #22 (option O-1, GO CTO 23/10 ; précondition Render levée par capture
# dashboard : JWT_SECRET présente sur foresy-api, lecture de présence uniquement).
# RED publics mesurés (23/10, seed 59372 : R-1 ×2, R-2) ; verrous R-3/R-4 verts — GREEN après T4.
# docs/technical/audits/[DONE]_2026_10_23_22_jwt_hardening_investigation.md (§6.2 design · §7 suivi — clôturé 23/10).
# Discipline : stubs infra uniquement (ENV / Rails.env) — aucun stub sur composant métier (règle P7).
# Surfaces ENV stubbées ([] et fetch) pour rester indépendant du choix d'implémentation T4.
RSpec.describe JsonWebToken, 'contrat de signature JWT (#22 — O-1)' do
  let(:dedicated_key) { "jwt22-r1-dedicated-#{SecureRandom.hex(32)}" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
  end

  describe 'R-1 — clé dédiée : la signature provient de JWT_SECRET dès que la variable est présente' do
    # RED attendu : la signature reste secret_key_base (constante boot, json_web_token.rb L28) →
    # le décodage avec JWT_SECRET lève JWT::VerificationError et le décodage avec secret_key_base réussit.
    # GREEN attendu T4 : clé lue à l appel (JWT_SECRET en priorité).
    it 'signe avec JWT_SECRET quand la variable est présente' do
      allow(ENV).to receive(:[]).with('JWT_SECRET').and_return(dedicated_key)
      allow(ENV).to receive(:fetch).with('JWT_SECRET', nil).and_return(dedicated_key)

      token = JsonWebToken.encode(user_id: 1, session_id: 'sess-r1')

      payload, _header = JWT.decode(token, dedicated_key)
      expect(payload['user_id']).to eq(1)
    end

    it 'ne signe plus avec secret_key_base quand la variable est présente' do
      allow(ENV).to receive(:[]).with('JWT_SECRET').and_return(dedicated_key)
      allow(ENV).to receive(:fetch).with('JWT_SECRET', nil).and_return(dedicated_key)

      token = JsonWebToken.encode(user_id: 2, session_id: 'sess-r1bis')

      expect { JWT.decode(token, Rails.application.secret_key_base) }
        .to raise_error(JWT::VerificationError)
    end
  end

  describe 'R-2 — fail-fast production : JWT_SECRET absente ⇒ refus de signer' do
    # RED mesuré (T3, seed 59372) : aucun garde n existait → encode réussissait silencieusement avec secret_key_base.
    # GREEN T4 : ConfigurationError levée explicitement quand JWT_SECRET est absente ou vide en production
    # (miroir RateLimit::RedisConfigurationError — contrat FC-05 A1).
    it 'refuse la signature en production sans JWT_SECRET' do
      allow(ENV).to receive(:[]).with('JWT_SECRET').and_return(nil)
      allow(ENV).to receive(:fetch).with('JWT_SECRET', nil).and_return(nil)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect { JsonWebToken.encode(user_id: 3, session_id: 'sess-r2') }
        .to raise_error(JsonWebToken::ConfigurationError)
    end
  end

  describe 'R-3 — fallback dev/test : secret_key_base reste la clé par défaut sans JWT_SECRET' do
    # Verrou (déjà vrai, à conserver après T4) : compatibilité des environnements non-production.
    it 'garde le comportement hérité hors production' do
      allow(ENV).to receive(:[]).with('JWT_SECRET').and_return(nil)
      allow(ENV).to receive(:fetch).with('JWT_SECRET', nil).and_return(nil)

      token = JsonWebToken.encode(user_id: 4, session_id: 'sess-r3')

      payload, _header = JWT.decode(token, Rails.application.secret_key_base)
      expect(payload['user_id']).to eq(4)
    end
  end

  describe 'R-4 — épinglage d algorithme : tout alg autre que HS256 est rejeté' do
    # Verrou : GREEN avant ET après T4 (épinglage incident du gem jwt 2.10.3 → explicite) — protège contre
    # le drift du défaut du gem lors d une upgrade jwt (probes §2.2 du doc : HS512/none rejetés).
    it 'rejette HS512 avec JWT::IncorrectAlgorithm, même avec une clé de forge dédiée' do
      forged = JWT.encode({ user_id: 5 }, dedicated_key, 'HS512')

      expect { JsonWebToken.decode(forged) }.to raise_error(JWT::IncorrectAlgorithm)
    end

    it 'rejette none avec JWT::IncorrectAlgorithm' do
      unsigned = JWT.encode({ user_id: 6 }, '', 'none')

      expect { JsonWebToken.decode(unsigned) }.to raise_error(JWT::IncorrectAlgorithm)
    end
  end
end
