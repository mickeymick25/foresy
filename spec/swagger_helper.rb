# frozen_string_literal: true

require 'rails_helper'
require 'rswag/specs'

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
      }
    }
  }

  # Format de sortie : YAML
  config.openapi_format = :yaml
end

# NOTE: Les tokens doivent être générés par AuthenticationService.login
# pour respecter le contrat FC-06 (session active requise)
#
# IMPORTANT: Ce shared_context ne crée PLUS d'utilisateur automatiquement.
# Chaque test DOIT définir son propre `user` via let(:user).
# Chaque test DOIT définir son propre token via let(:user_token) ou let(:Authorization).
#
# Exemple de setup dans un test :
#   let(:user) { create(:user) }
#   let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test')[:token] }
#   let(:headers) { { 'Authorization' => "Bearer #{user_token}" } }
#
# Ce shared_context reste disponible pour la rétrocompatibilité des configs rswag.

RSpec.configure do |config|
  # NOTE: shared_context 'with_authenticated_user' was removed
  # Each test is now responsible for creating its own user and token
  # See comments above for the recommended pattern
end
