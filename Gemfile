# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.8'

# Core Rails gems
gem 'bcrypt', '~> 3.1.18'
gem 'bootsnap', require: false
gem 'importmap-rails'
gem 'jbuilder'
gem 'jwt', '~> 2.7'
gem 'omniauth'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'rack-cors'
gem 'rails', '~> 8.1.1'
gem 'sprockets-rails'
gem 'stimulus-rails'
gem 'turbo-rails'

# For Windows compatibility
gem 'tzinfo-data', platforms: %i[windows jruby]

# == Development & Test ==
group :development, :test do
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'debug', platforms: %i[mri windows]
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'rspec' # <- sécurité si RSpec core non inclus
  gem 'rspec-rails'
  gem 'rswag'
  gem 'rswag-specs'
  gem 'rswag-ui'
  gem 'rubocop', require: false
end

# == Development Only ==
group :development do
  gem 'rack-mini-profiler'
  gem 'spring'
  gem 'web-console'
end

# == Test Only ==
group :test do
  gem 'capybara'
  gem 'faker'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.0'
end
