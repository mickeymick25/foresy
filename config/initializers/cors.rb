Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*' # À remplacer par l'URL de votre frontend en production

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization']
  end
end 