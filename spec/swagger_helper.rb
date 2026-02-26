# frozen_string_literal: true

require 'rails_helper'
require 'rswag/specs'

RSpec.configure do |config|
  # Dossier où seront générés les fichiers Swagger
  config.openapi_root = Rails.root.join('swagger').to_s

  # Mode strict : rejecte les champs inconnus (additionalProperties: false)
  # Phase 1.6 - API Contract Hardening
  config.openapi_no_additional_properties = true

  # Définition des spécifications OpenAPI
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API Foresy',
        version: 'v1',
        description: <<-DESC
          Documentation de l'API Foresy

          ## API Versioning Policy
          L'API Foresy utilise le versioning par URL : `/api/v1/`, `/api/v2/`, etc.

          ### Breaking Changes
          - Breaking changes nécessitent une nouvelle version majeure
          - Période de dépréciation : 12 mois (actif) + 3 mois (deprecated)
          - Voir : [API Versioning Policy](./docs/technical/corrections/2026-02-18-RSwag_Completion_Status-Phase_1.8-API_Versioning_Policy.md)

          ### Deprecation Headers
          Les endpoints dépréciés retournent les headers suivants :
          - `X-API-Deprecated` : true si l'endpoint est déprécié
          - `X-API-Sunset` : Date de suppression (YYYY-MM-DD)
          - `X-API-Warning` : Message d'avertissement
          - `Deprecation` : Header RFC 8244 compliant

          Ces headers sont optionnels et seulement présents quand l'endpoint est déprécié.
        DESC
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
        headers: {
          'X-API-Deprecated' => {
            schema: { type: :string },
            description: 'Set to true if the endpoint is deprecated. Optional - only when deprecated.'
          },
          'X-API-Sunset' => {
            schema: { type: :string, format: :date },
            description: 'Date when the endpoint will be removed (YYYY-MM-DD). Optional - only when deprecated.'
          },
          'X-API-Warning' => {
            schema: { type: :string },
            description: 'Warning message about deprecation and migration. Optional - only when deprecated.'
          },
          'Deprecation' => {
            schema: { type: :string },
            description: 'RFC 8244 compliant header. Optional - only when deprecated.'
          }
        },
        schemas: {
          user: {
            type: :object,
            additionalProperties: false,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password },
              password_confirmation: { type: :string, format: :password }
            },
            required: %w[email password password_confirmation]
          },
          # =============================================
          # REQUEST SCHEMAS - Centralized with strict mode
          # Phase 1.6 - All have additionalProperties: false
          # =============================================

          loginRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[email password],
            properties: {
              email: { type: :string, format: :email, description: 'User email address' },
              password: { type: :string, format: :password, description: 'User password' }
            }
          },

          RefreshTokenRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[refresh_token],
            properties: {
              refresh_token: { type: :string, description: 'Refresh token to renew access token' }
            }
          },

          OAuthCallbackRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[code redirect_uri],
            properties: {
              code: { type: :string, description: 'OAuth authorization code from provider' },
              redirect_uri: { type: :string, format: :uri, description: 'Redirect URI used in OAuth flow' }
            }
          },

          UserCreateRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[email password password_confirmation],
            properties: {
              email: { type: :string, format: :email, description: 'User email address' },
              password: { type: :string, format: :password, description: 'User password' },
              password_confirmation: { type: :string, format: :password, description: 'Password confirmation' }
            }
          },

          MissionCreateRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[name mission_type],
            properties: {
              name: { type: :string, description: 'Mission name' },
              description: { type: :string, description: 'Mission description' },
              mission_type: { type: :string, enum: %w[time_based fixed_price], description: 'Mission type' },
              status: { type: :string, enum: %w[lead pending won in_progress completed],
                        description: 'Mission status' },
              start_date: { type: :string, format: :date, description: 'Mission start date' },
              daily_rate: { type: :integer, description: 'Daily rate in cents' },
              fixed_price: { type: :integer, description: 'Fixed price in cents' },
              currency: { type: :string, description: 'Currency code (e.g., EUR)' },
              client_company_id: { type: :string, format: :uuid, description: 'Client company UUID' }
            }
          },

          MissionUpdateRequest: {
            type: :object,
            additionalProperties: false,
            required: [],
            properties: {
              name: { type: :string, description: 'Mission name' },
              description: { type: :string, description: 'Mission description' },
              mission_type: { type: :string, enum: %w[time_based fixed_price], description: 'Mission type' },
              status: { type: :string, enum: %w[lead pending won in_progress completed],
                        description: 'Mission status' },
              start_date: { type: :string, format: :date, description: 'Mission start date' },
              daily_rate: { type: :integer, description: 'Daily rate in cents' },
              fixed_price: { type: :integer, description: 'Fixed price in cents' },
              currency: { type: :string, description: 'Currency code (e.g., EUR)' },
              client_company_id: { type: :string, format: :uuid, description: 'Client company UUID' }
            }
          },

          CraCreateRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[month year],
            properties: {
              month: { type: :integer, description: 'Month (1-12)', example: 1 },
              year: { type: :integer, description: 'Year (e.g., 2026)', example: 2026 },
              currency: { type: :string, description: 'Currency code (e.g., EUR)', example: 'EUR' },
              description: { type: :string, description: 'CRA description' },
              status: { type: :string, enum: %w[draft submitted locked], description: 'CRA status',
                        example: 'draft' }
            }
          },

          CraUpdateRequest: {
            type: :object,
            additionalProperties: false,
            required: [],
            properties: {
              month: { type: :integer, description: 'Month (1-12)' },
              year: { type: :integer, description: 'Year (e.g., 2026)' },
              currency: { type: :string, description: 'Currency code (e.g., EUR)' },
              description: { type: :string, description: 'CRA description' },
              status: { type: :string, enum: %w[draft submitted locked], description: 'CRA status' }
            }
          },

          CraEntryCreateRequest: {
            type: :object,
            additionalProperties: false,
            required: %w[date quantity unit_price description mission_id],
            properties: {
              date: { type: :string, format: :date, description: 'Entry date' },
              quantity: { type: :number, description: 'Quantity (days or hours)' },
              unit_price: { type: :integer, description: 'Unit price in cents' },
              description: { type: :string, description: 'Entry description' },
              mission_id: { type: :string, format: :uuid, description: 'Mission ID (UUID)' }
            }
          },

          CraEntryUpdateRequest: {
            type: :object,
            additionalProperties: false,
            required: [],
            properties: {
              date: { type: :string, format: :date, description: 'Entry date' },
              quantity: { type: :number, description: 'Quantity (days or hours)' },
              unit_price: { type: :integer, description: 'Unit price in cents' },
              description: { type: :string, description: 'Entry description' },
              mission_id: { type: :string, format: :uuid, description: 'Mission ID (UUID)' }
            }
          },

          login: {
            type: :object,
            additionalProperties: false,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password }
            },
            required: %w[email password]
          },
          # Error schema - unified error structure for all API errors
          # Used by: 400, 401, 403, 404, 422, 500 responses
          Error: {
            type: :object,
            required: %w[error],
            additionalProperties: false,
            properties: {
              error: {
                type: :object,
                required: %w[code message],
                additionalProperties: false,
                properties: {
                  code: {
                    type: :string,
                    description: 'Error code (e.g., not_found, validation_failed, internal_error)'
                  },
                  message: {
                    type: :string,
                    description: 'Human-readable error message'
                  },
                  details: {
                    type: :array,
                    description: 'Optional array of error details',
                    items: {
                      type: :object,
                      additionalProperties: true
                    }
                  }
                }
              }
            }
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
