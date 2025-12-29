# frozen_string_literal: true

# Charger les variables d'environnement spécifiques au test
require 'dotenv'
Dotenv.load('.env.test') if File.exist?('.env.test')

# Configuration de l'environnement de test
ENV['RAILS_ENV'] ||= 'test'
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

  # Clear rate limiting cache between tests to avoid 429 errors
  config.before(:each) do
    # Clear rate limits for common test IPs and endpoints
    ['127.0.0.1', '192.168.1.1', '10.0.0.1'].each do |ip|
      ['auth/login', 'auth/signup', 'auth/refresh'].each do |endpoint|
        RateLimitService.clear_rate_limit(endpoint, ip) if defined?(RateLimitService)
      end
    end
  end

  # Mode test pour OmniAuth
  OmniAuth.config.test_mode = true
end

# Shoulda Matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
