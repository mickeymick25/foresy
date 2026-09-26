# frozen_string_literal: true

# FC-05 — Contrat de rate limiting (cible v1, arbitré CTO 25/09/2026)
#
# Contrat      : docs/technical/guides/2026_09_25_fc05_rate_limiting_contract.md
# Investigation: docs/technical/audits/[DONE]_2026_09_25_fc05_rate_limiting_audit.md (BACKLOG #20)
# Chantier     : BACKLOG #23 — RED contractuels. ARRÊT AVANT GREEN (aucune implémentation).
#
# Statut attendu : 🔴 RED — ces specs échouent pour les raisons documentées par #20 :
#   C-1 : sélecteur inconditionnel MemoryBackend (rate_limit_service.rb L45)
#   C-2 : compteur jamais incrémenté côté Redis (RedisRateLimiter#increment! orphelin)
#   C-3 : LIMITS sans clés missions/cras/cra_entries
#   +   : fail-closed masquant (StandardError → 429) contredit A3/A4
RSpec.describe 'FC-05 — contrat de rate limiting (cible v1)' do
  let(:logger) { double('logger', info: nil, warn: nil, error: nil) }

  before do
    RateLimitService.remove_instance_variable(:@backend) if RateLimitService.instance_variable_defined?(:@backend)
    allow(Rails).to receive(:logger).and_return(logger)
  end

  def with_env(redis_url)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('REDIS_URL', any_args).and_return(redis_url)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('REDIS_URL').and_return(redis_url)
  end

  describe 'RED 1 — sélection du backend (6 états du contrat §2)' do
    it 'état 1 — REDIS_URL absente en dev/test → MemoryBackend' do
      with_env(nil)
      expect(RateLimitService.backend).to be_a(RateLimit::MemoryBackend)
    end

    it 'état 2 — REDIS_URL absente en PRODUCTION → RedisConfigurationError explicite (A1)' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      with_env(nil)
      expect { RateLimitService.backend }.to raise_error(/REDIS_URL/i)
    end

    it 'état 3 — REDIS_URL présente, Redis joignable → RedisBackend (protection distribuée)' do
      with_env(ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      expect(RateLimitService.backend).to be_a(RateLimit::RedisBackend)
    end

    it 'état 4 — REDIS_URL présente, Redis indisponible → fallback MemoryBackend + warning structuré (A2)' do
      allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError, 'connection refused')
      expect(RateLimitService.backend).to be_a(RateLimit::MemoryBackend)
      expect(logger).to have_received(:warn).with(a_string_including('rate_limit.backend_fallback'))
    end

    it 'état 5 — timeout Redis → même contrat de dégradation (A2)' do
      allow(Redis).to receive(:new).and_raise(Redis::TimeoutError, 'timeout')
      expect(RateLimitService.backend).to be_a(RateLimit::MemoryBackend)
      expect(logger).to have_received(:warn).with(a_string_including('rate_limit.backend_fallback'))
    end

    it 'état 6 — erreur interne inattendue → JAMAIS de 429 : erreur explicite propagée (A3/A4)' do
      backend_stub = RateLimit::MemoryBackend.new
      allow(RateLimit::MemoryBackend).to receive(:new).and_return(backend_stub)
      allow(backend_stub).to receive(:increment).and_raise(RuntimeError, 'bug interne inattendu')
      RateLimitService.instance_variable_set(:@backend, backend_stub)

      expect {
        RateLimitService.check_rate_limit('auth/login', '1.2.3.4')
      }.to raise_error(RuntimeError, /bug interne/)
      expect(logger).to have_received(:error).with(a_string_including('rate_limit'))
    end
  end

  describe 'RED 2 — compteur end-to-end via check_rate_limit (contrat §3)' do
    it 'limite 1 : requête 1 autorisée, requête 2 refusée' do
      stub_const('RateLimitService::LIMITS', { 'auth/login' => 1 })

      first = RateLimitService.check_rate_limit('auth/login', '9.9.9.9')
      second = RateLimitService.check_rate_limit('auth/login', '9.9.9.9')

      expect(first).to eq([true, 0])
      expect(second).to eq([false, 60])
    end

    it 'le compteur vit dans le backend SÉLECTIONNÉ (Redis quand la protection est distribuée)' do
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      redis.del('rate_limit:auth/login:8.8.8.8')

      3.times { RateLimitService.check_rate_limit('auth/login', '8.8.8.8') }

      expect(redis.get('rate_limit:auth/login:8.8.8.8')).to eq('3')
      redis.del('rate_limit:auth/login:8.8.8.8')
    end
  end

  describe 'RED 3 — missions (contrat §3, A7)' do
    it 'LIMITS contient les clés contractuelles missions' do
      expect(RateLimitService::LIMITS).to include('missions:create' => 20, 'missions:update' => 60)
    end

    it 'end-to-end : 20 créations autorisées par user, la 21e refusée (clé user_id, fenêtre 1 h)' do
      stub_const('RateLimitService::LIMITS', { 'missions:create' => 20 })

      results = 21.times.map { RateLimitService.check_rate_limit('missions:create', 'user-42') }

      expect(results.first(20)).to all(eq([true, 0]))
      expect(results.last).to eq([false, 3600])
    end
  end

  describe 'RED 4 — CRA / entries (contrat §3, A8)' do
    it 'LIMITS contient les clés contractuelles cras:* et cra_entries:*' do
      expect(RateLimitService::LIMITS).to include(
        'cras:create' => 10,
        'cras:update_destroy' => 50,
        'cras:submit_lock' => 5,
        'cra_entries:create' => 20,
        'cra_entries:create_burst' => 5,
        'cra_entries:update_destroy' => 50
      )
    end

    it 'end-to-end : rafale entries 5/10 min par user, la 6e refusée' do
      stub_const('RateLimitService::LIMITS', { 'cra_entries:create_burst' => 5 })

      results = 6.times.map { RateLimitService.check_rate_limit('cra_entries:create_burst', 'user-7') }

      expect(results.first(5)).to all(eq([true, 0]))
      expect(results.last).to eq([false, 600])
    end
  end
end