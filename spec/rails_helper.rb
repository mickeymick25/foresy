# frozen_string_literal: true

# ============================================
# 🚀 Foresy Test Environment Lockdown
# ============================================
# Ce fichier garantit un environnement de test DÉTERMINISTE
# pour JWT, OAuth et Rate Limiting.
# NE PAS modifier sans justification technique.

# Charger les variables d'environnement spécifiques au test
require 'dotenv'
Dotenv.load('.env.test') if File.exist?('.env.test')

# Configuration de l'environnement de test
ENV['RAILS_ENV'] ||= 'test'

# ============================================
# 🔐 VERRouillage des Secrets JWT/OAuth
# ============================================
# TOUS les tests doivent utiliser les mêmes secrets
# pour garantir la reproductibilité (seed-proof)
ENV['JWT_SECRET'] ||= 'test_jwt_secret_key_for_rspec_deterministic_testing_32chars!!'
ENV['JWT_EXPIRATION'] ||= '3600'
ENV['JWT_REFRESH_EXPIRATION'] ||= '604800'

ENV['OAUTH_CLIENT_ID'] ||= 'test_client_id'
ENV['OAUTH_CLIENT_SECRET'] ||= 'test_client_secret'
ENV['OAUTH_REDIRECT_URI'] ||= 'http://localhost:3000/api/v1/auth/:provider/callback'

ENV['GOOGLE_CLIENT_ID'] ||= ENV.fetch('OAUTH_CLIENT_ID', nil)
ENV['GOOGLE_CLIENT_SECRET'] ||= ENV.fetch('OAUTH_CLIENT_SECRET', nil)

ENV['GITHUB_CLIENT_ID'] ||= ENV.fetch('OAUTH_CLIENT_ID', nil)
ENV['GITHUB_CLIENT_SECRET'] ||= ENV.fetch('OAUTH_CLIENT_SECRET', nil)
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'spec_helper'
require 'rspec/rails'
require 'shoulda/matchers'
require 'faker'

# Charger les fichiers de support (helpers, macros, etc.)
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# S'assurer que la base est bien migrée avant les tests
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

# Configuration RSpec
RSpec.configure do |config|
  config.fixture_paths = ["#{Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include AuthHelpers, type: :request
  config.include JwtHelpers, type: :request

  # ============================================
  # 🧹 Cleanup Rate Limiting entre chaque test
  # ============================================
  # NOTE: On ne stubbe PLUS RateLimitService globalement.
  # Les specs d'auth (login, signup, refresh) stubbent RateLimitService
  # DANS LEURS SPECS si nécessaire.
  # Les specs FC-05 (rate_limiting_api_integration_spec.rb) doivent
  # tester le vrai comportement rate limiting.
  config.before(:each) do
    if defined?(RateLimitService)
      # Nettoyage des rate limits pour les IPs de test
      ['127.0.0.1', '192.168.1.1', '10.0.0.1', '0.0.0.0'].each do |ip|
        ['auth/login', 'auth/signup', 'auth/refresh', 'auth/logout'].each do |endpoint|
          RateLimitService.clear_rate_limit(endpoint, ip)
        rescue StandardError
          nil
        end
      end
    end
  end

  # ============================================
  # 🔐 Configuration OmniAuth (Test Mode)
  # ============================================
  OmniAuth.config.test_mode = true

  # Nettoyage des mocks OAuth après chaque test
  config.after(:each) do
    OmniAuth.config.mock_auth.clear
  end
end

# Shoulda Matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
