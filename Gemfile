# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.0'

# Core Rails gems
gem 'rails', '~> 7.1.5', '>= 7.1.5.1'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'bootsnap', require: false
gem 'sprockets-rails'
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'jbuilder'
gem 'bcrypt', '~> 3.1.18'
gem 'jwt', '~> 2.7'
gem 'rack-cors'

# For Windows compatibility
gem 'tzinfo-data', platforms: %i[windows jruby]

# == Development & Test ==
group :development, :test do
  gem 'rspec-rails'
  gem 'rspec' # <- sécurité si RSpec core non inclus
  gem 'rswag'
  gem 'rswag-specs'
  gem 'rswag-ui'
  gem 'factory_bot_rails'
  gem 'rubocop', require: false
  gem 'debug', platforms: %i[mri windows]
end

# == Development Only ==
group :development do
  gem 'spring'
  gem 'rack-mini-profiler'
  gem 'web-console'
end

# == Test Only ==
group :test do
  gem 'capybara'
  gem 'faker'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.0'
end
