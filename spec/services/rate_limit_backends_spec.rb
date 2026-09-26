# frozen_string_literal: true

require 'rails_helper'

# W3-D3 — Caractérisation Rate Limit (FC-05) : backends + helpers RateLimitService
#
# - RateLimit::Backend : contrat abstrait (NotImplementedError ×3)
# - RateLimit::RedisBackend : sliding window ZSET sur le Redis RÉEL du conteneur
#   (aucun stub réseau — la connexion passe par RateLimitService.redis, L59-63)
# - RateLimitService : helpers de monitoring/contrat (current_count,
#   rate_limited_endpoint?, extract_endpoint, mask_ip)
RSpec.describe RateLimit::RedisBackend, type: :service do
  let(:backend) { described_class.new }
  let(:key) { "w3-d3:#{SecureRandom.hex(8)}" }

  after do
    backend.clear(key)
  rescue StandardError
    nil
  end

  describe 'sliding window ZSET (Redis réel)' do
    it 'incrément retourne le nouveau compteur dans la fenêtre' do
      first = backend.increment(key, window: 60)
      second = backend.increment(key, window: 60)

      expect(first).to eq(1)
      expect(second).to eq(2)
      expect(backend.count(key, window: 60)).to eq(2)
    end

    it 'purge les entrées expirées hors fenêtre (zremrangebyscore)' do
      stale = Time.current.to_f - 120 # hors fenêtre de 60 s
      allow(Time).to receive(:current).and_return(Time.at(stale))
      backend.increment(key, window: 60)
      allow(Time).to receive(:current).and_call_original

      result = backend.increment(key, window: 60) # purge le stale, ajoute le courant

      expect(result).to eq(1)
      expect(backend.count(key, window: 60)).to eq(1)
    end

    it 'clear supprime toutes les entrées de la clé' do
      backend.increment(key, window: 60)
      backend.increment(key, window: 60)

      backend.clear(key)

      expect(backend.count(key, window: 60)).to eq(0)
    end

    it 'obtient la connexion Redis via RateLimitService.redis (L59-63)' do
      connection = RateLimitService.send(:redis)

      expect(connection).to respond_to(:zadd)
    end
  end
end

RSpec.describe RateLimit::Backend, type: :service do
  it 'impose increment aux sous-classes (contrat abstrait)' do
    expect { described_class.new.increment('k', window: 60) }
      .to raise_error(NotImplementedError, /must be implemented/)
  end

  it 'impose count aux sous-classes (contrat abstrait)' do
    expect { described_class.new.count('k', window: 60) }
      .to raise_error(NotImplementedError, /must be implemented/)
  end

  it 'impose clear aux sous-classes (contrat abstrait)' do
    expect { described_class.new.clear('k') }
      .to raise_error(NotImplementedError, /must be implemented/)
  end
end

RSpec.describe RateLimitService, type: :service do
  describe '.current_count (monitoring/debug)' do
    it 'retourne le compteur courant via le backend injecté (même instance)' do
      backend = RateLimit::MemoryBackend.new
      service = described_class.new(backend: backend)

      service.check_rate_limit('auth/login', '10.0.0.1')

      expect(service.current_count('auth/login', '10.0.0.1')).to eq(1)
    end

    it 'retourne 0 sur une instance neuve avec le MemoryBackend (compteur par instance)' do
      expect(described_class.current_count('auth/login', '10.0.0.1')).to eq(0)
    end
  end

  describe '.rate_limited_endpoint?' do
    it 'identifie les endpoints du contrat FC-05' do
      expect(described_class.rate_limited_endpoint?('/api/v1/auth/login')).to be(true)
      expect(described_class.rate_limited_endpoint?('/api/v1/unknown/path')).to be(false)
      expect(described_class.rate_limited_endpoint?('/api/v1/missions')).to be(false) # 'missions' seul n'est pas une clé
    end
  end

  describe '#mask_ip (branches de masquage)' do
    it 'masque une IPv4 en x.x' do
      expect(described_class.new.send(:mask_ip, '192.168.10.42')).to eq('192.168.x.x')
    end

    it 'masque une IPv6 partiellement' do
      expect(described_class.new.send(:mask_ip, '2001:db8::1')).to eq('2001:db8:...:x')
    end

    it 'retourne unknown tel quel' do
      expect(described_class.new.send(:mask_ip, 'unknown')).to eq('unknown')
      expect(described_class.new.send(:mask_ip, nil)).to eq('unknown')
    end
  end
end
