# frozen_string_literal: true

Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'health' => 'rails/health#show', as: :health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'authentication#login'
      post 'auth/refresh', to: 'authentication#refresh'
      delete 'auth/logout', to: 'authentication#logout'
      post 'auth/:provider/callback', to: 'oauth#callback'
      get 'auth/failure', to: 'oauth#failure'
      post 'signup', to: 'users#create'
    end
  end

  # Pour éviter une 404 inutile sur la racine, Définir une racine propre pour l'API
  root to: proc { [200, { 'Content-Type' => 'application/json' }, ['{"status":"API is live"}']] }

  # Ou pour retourner une 404 propre :
  # root to: proc { [404, {}, ['Not Found']] }
end
