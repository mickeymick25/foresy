# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'rails_helper'

RSpec.configure do |config|
  # Dossier où seront générés les fichiers Swagger
  config.openapi_root = Rails.root.join('swagger').to_s

  # Définition des spécifications OpenAPI
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API Foresy',
        version: 'v1',
        description: 'Documentation de l\'API Foresy'
      },
      paths: {},
      servers: [
        {
          url: 'http://{defaultHost}',
          description: 'Serveur local de développement',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
          }
        },
        schemas: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password },
              password_confirmation: { type: :string, format: :password }
            },
            required: %w[email password password_confirmation]
          },
          login: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password }
            },
            required: %w[email password]
          }
        }
      },
      security: [
        { bearer_auth: [] }
      ]
    }
  }

  # Format de sortie : YAML
  config.openapi_format = :yaml
end

# Ajout global du header Authorization pour les tests request specs
RSpec.shared_context 'with_authenticated_user', shared_context: :metadata do
  let(:Authorization) { 'Bearer dummy_token' }
end

RSpec.configure do |config|
  config.include_context 'with_authenticated_user', type: :request
end
# rubocop:enable Metrics/BlockLength
