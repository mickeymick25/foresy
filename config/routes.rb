# frozen_string_literal: true

Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'up' => 'health#up', as: :rails_health_check
  get 'health' => 'health#show', as: :health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'authentication#login'
      post 'auth/refresh', to: 'authentication#refresh'
      delete 'auth/logout', to: 'authentication#logout'
      delete 'auth/revoke', to: 'authentication#revoke'
      delete 'auth/revoke_all', to: 'authentication#revoke_all'
      post 'auth/:provider/callback', to: 'oauth#callback'
      get 'auth/failure', to: 'oauth#failure'
      post 'signup', to: 'users#create'
      resources :missions, only: %i[index show create update destroy]
    end
  end

  # E2E Test Support Routes - ONLY mounted in test mode or when E2E_MODE=true
  # 🔐 SECURITY: These routes are NOT accessible in production
  # ⚠️ Any exposure in production is a CRITICAL security flaw
  if Rails.env.test? || ENV['E2E_MODE'] == 'true'
    namespace :__test_support__, path: '__test_support__' do
      namespace :e2e, path: 'e2e' do
        post 'setup', to: 'setup#create'
        delete 'cleanup', to: 'setup#destroy'
      end
    end
  end

  # Pour éviter une 404 inutile sur la racine, Définir une racine propre pour l'API
  root to: proc { [200, { 'Content-Type' => 'application/json' }, ['{"status":"API is live"}']] }

  # Ou pour retourner une 404 propre :
  # root to: proc { [404, {}, ['Not Found']] }
end
