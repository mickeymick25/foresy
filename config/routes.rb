# frozen_string_literal: true

Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'authentication#login'
      post 'auth/refresh', to: 'authentication#refresh'
      delete 'auth/logout', to: 'authentication#logout'
      post 'signup', to: 'users#create'
      resources :users, only: [:create]
    end
  end
end
