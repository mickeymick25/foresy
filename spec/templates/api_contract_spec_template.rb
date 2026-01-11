# Template pour Tests d'API Contract (RSwag)
# Ce template est utilisé pour créer des tests de contrat API
# Il ne doit PAS contenir de logique métier pure
#
# Usage:
#   cp spec/templates/api_contract_spec_template.rb spec/requests/my_feature_contract_spec.rb
#   Personnaliser le contenu selon l'endpoint à tester

require 'rails_helper'

# ==============================================================================
# API CONTRACT TEST TEMPLATE
# ==============================================================================
#
# RÈGLES IMPORTANTES:
# ✅ Ce template est pour les CONTRATS API UNIQUEMENT
# ✅ Il teste les schémas, paramètres, réponses HTTP
# ✅ Il NE teste PAS la logique métier pure
# ✅ Il utilise les types RSwag: :rswag, :swagger_doc
#
# POUR LA LOGIQUE MÉTIER, utiliser:
#   spec/templates/business_logic_spec_template.rb

RSpec.describe 'API Contract Tests', type: :rswag, swagger_doc: 'swagger/v1/swagger.yaml' do
  include ApiContractHelpers

  # ============================================================================
  # CONFIGURATION COMMUNE
  # ============================================================================

  # Helper methods disponibles:
  # - authenticated_header(user) : Génère un header Authorization valide
  # - invalid_header() : Génère un header invalide pour test d'erreur
  # - create_test_user : Crée un utilisateur de test avec token
  # - cra_setup : Setup pour tests CRA (basé sur e2e_cra_lifecycle_fc07.sh)

  # ============================================================================
  # GROUPE DE TESTS PRINCIPAL
  # ============================================================================

  describe 'FC-07 CRA Lifecycle Contract' do
    let(:valid_user) { create(:user) }
    let(:valid_headers) { authenticated_header(valid_user) }

    # ------------------------------------------------------------------------
    # ENDPOINT: POST /api/v1/cras
    # ------------------------------------------------------------------------

    path '/api/v1/cras' do
      post 'Creates a CRA' do
        tags 'CRA'
        description 'Creates a CRA with month/year validation. Based on FC-07 specification.'
        consumes 'application/json'
        produces 'application/json'

        # ------------------------------------------------------------------------
        # PARAMÈTRES
        # ------------------------------------------------------------------------

        parameter name: :Authorization,
                  in: :header,
                  type: :string,
                  required: true,
                  description: 'Bearer token for authentication'

        parameter name: :body,
                  in: :body,
                  schema: { '$ref' => '#/definitions/cra_request' },
                  required: true

        # ------------------------------------------------------------------------
        # RÉPONSES ATTENDUES
        # ------------------------------------------------------------------------

        response 201, 'CRA created successfully' do
          schema type: :object,
                 properties: {
                   data: {
                     type: :object,
                     properties: {
                       cra: { '$ref' => '#/definitions/cra_response' }
                     }
                   },
                   message: { type: :string },
                   timestamp: { type: :string }
                 },
                 required: %w[data message timestamp]

          let(:Authorization) { valid_headers }
          let(:body) do
            {
              month: 1,
              year: 2025,
              currency: 'EUR',
              description: 'Test CRA for contract validation'
            }
          end

          it_behaves_like 'successful cra creation'
        end

        response 400, 'Invalid parameters' do
          schema { '$ref' => '#/definitions/error' }

          let(:Authorization) { valid_headers }
          let(:body) do
            {
              month: 13, # Month invalide
              year: 2025,
              currency: 'EUR'
            }
          end

          it_behaves_like 'parameter validation error'
        end

        response 401, 'Unauthorized' do
          let(:Authorization) { invalid_header }
          let(:body) do
            {
              month: 1,
              year: 2025,
              currency: 'EUR'
            }
          end

          it_behaves_like 'authentication required'
        end

        response 422, 'Business rule violation' do
          schema { '$ref' => '#/definitions/error' }

          let(:Authorization) { valid_headers }
          let(:body) do
            {
              month: 1,
              year: 2025,
              currency: 'EUR'
            }
          end

          # Setup: créer un CRA existant pour ce user/month/year
          before do
            create(:cra,
                   user: valid_user,
                   month: 1,
                   year: 2025)
          end

          it_behaves_like 'cra uniqueness constraint'
        end
      end
    end

    # ------------------------------------------------------------------------
    # ENDPOINT: POST /api/v1/cras/{cra_id}/entries
    # ------------------------------------------------------------------------

    path '/api/v1/cras/{cra_id}/entries' do
      post 'Creates a CRA Entry' do
        tags 'CRA Entry'
        description 'Creates an entry for a specific CRA'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :cra_id,
                  in: :path,
                  type: :string,
                  format: :uuid,
                  required: true,
                  description: 'UUID of the CRA'

        parameter name: :Authorization,
                  in: :header,
                  type: :string,
                  required: true

        parameter name: :body,
                  in: :body,
                  schema: { '$ref' => '#/definitions/cra_entry_request' },
                  required: true

        response 201, 'CRA Entry created successfully' do
          schema type: :object,
                 properties: {
                   data: {
                     type: :object,
                     properties: {
                       entry: { '$ref' => '#/definitions/cra_entry_response' },
                       cra: { '$ref' => '#/definitions/cra_response' },
                       totals_updated: {
                         type: :object,
                         properties: {
                           cra_total_days: { type: :number },
                           cra_total_amount: { type: :integer },
                           currency: { type: :string }
                         }
                       }
                     }
                   },
                   message: { type: :string },
                   timestamp: { type: :string }
                 }

          # Setup pour ce test
          let(:Authorization) { valid_headers }
          let(:cra_id) { create(:cra, user: valid_user).id }
          let(:body) do
            {
              date: '2025-01-10',
              quantity: 0.5,
              unit_price: 60_000,
              description: 'Test entry for contract validation',
              mission_id: create(:mission, user: valid_user).id
            }
          end

          it_behaves_like 'successful cra entry creation'
        end

        response 400, 'Invalid entry parameters' do
          schema { '$ref' => '#/definitions/error' }

          let(:Authorization) { valid_headers }
          let(:cra_id) { create(:cra, user: valid_user).id }
          let(:body) do
            {
              date: 'invalid-date', # Date invalide
              quantity: 0.5,
              unit_price: 60_000,
              mission_id: create(:mission, user: valid_user).id
            }
          end

          it_behaves_like 'entry parameter validation error'
        end

        response 404, 'CRA not found' do
          schema { '$ref' => '#/definitions/error' }

          let(:Authorization) { valid_headers }
          let(:cra_id) { SecureRandom.uuid } # CRA inexistant
          let(:body) do
            {
              date: '2025-01-10',
              quantity: 0.5,
              unit_price: 60_000,
              mission_id: create(:mission, user: valid_user).id
            }
          end

          it_behaves_like 'cra not found error'
        end
      end
    end

    # ------------------------------------------------------------------------
    # ENDPOINT: GET /api/v1/cras/{cra_id}
    # ------------------------------------------------------------------------

    path '/api/v1/cras/{cra_id}' do
      get 'Retrieves a CRA' do
        tags 'CRA'
        description 'Retrieves CRA details with entries'
        produces 'application/json'

        parameter name: :cra_id,
                  in: :path,
                  type: :string,
                  format: :uuid,
                  required: true

        parameter name: :Authorization,
                  in: :header,
                  type: :string,
                  required: true

        response 200, 'CRA retrieved successfully' do
          schema type: :object,
                 properties: {
                   id: { type: :string, format: :uuid },
                   month: { type: :integer },
                   year: { type: :integer },
                   status: { type: :string, enum: %w[draft submitted locked] },
                   description: { type: :string },
                   total_days: { type: :number },
                   total_amount: { type: :integer },
                   currency: { type: :string },
                   created_at: { type: :string, format: :date_time },
                   updated_at: { type: :string, format: :date_time },
                   entries: {
                     type: :array,
                     items: { '$ref' => '#/definitions/cra_entry_response' }
                   }
                 },
                 required: %w[id month year status total_days total_amount currency]

          let(:Authorization) { valid_headers }
          let(:cra_id) { create(:cra, user: valid_user).id }

          it_behaves_like 'successful cra retrieval'
        end

        response 401, 'Unauthorized' do
          let(:Authorization) { invalid_header }
          let(:cra_id) { create(:cra, user: valid_user).id }

          it_behaves_like 'authentication required'
        end

        response 404, 'CRA not found' do
          let(:Authorization) { valid_headers }
          let(:cra_id) { SecureRandom.uuid }

          it_behaves_like 'cra not found error'
        end
      end
    end
  end

  # ============================================================================
  # SHARED EXAMPLES (COMPORTEMENTS COMMUNS)
  # ============================================================================

  shared_examples 'successful cra creation' do
    it 'returns HTTP 201' do
      expect(response).to have_http_status(:created)
    end

    it 'returns valid CRA schema' do
      expect(response.body).to match_json_schema('cra_response')
    end

    it 'includes timestamp' do
      expect(JSON.parse(response.body)).to have_key('timestamp')
    end

    it 'includes success message' do
      expect(JSON.parse(response.body)['message']).to include('created successfully')
    end
  end

  shared_examples 'successful cra entry creation' do
    it 'returns HTTP 201' do
      expect(response).to have_http_status(:created)
    end

    it 'returns valid entry schema' do
      expect(response.body).to match_json_schema('cra_entry_response')
    end

    it 'includes updated totals' do
      response_data = JSON.parse(response.body)
      expect(response_data['data']).to have_key('totals_updated')
      expect(response_data['data']['totals_updated']).to have_key('cra_total_days')
      expect(response_data['data']['totals_updated']).to have_key('cra_total_amount')
    end

    it 'calculates line_total correctly' do
      response_data = JSON.parse(response.body)
      entry = response_data['data']['entry']
      expected_total = entry['quantity'].to_f * entry['unit_price'].to_i
      expect(entry['line_total']).to eq(expected_total)
    end
  end

  shared_examples 'successful cra retrieval' do
    it 'returns HTTP 200' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns valid CRA schema' do
      expect(response.body).to match_json_schema('cra')
    end

    it 'includes all required fields' do
      expect(response.body).to match_json_schema('cra')
    end

    it 'calculates totals correctly' do
      cra_data = JSON.parse(response.body)
      if cra_data['entries'].any?
        expected_total_days = cra_data['entries'].sum { |e| e['quantity'].to_f }
        expected_total_amount = cra_data['entries'].sum { |e| e['line_total'].to_i }

        expect(cra_data['total_days']).to eq(expected_total_days)
        expect(cra_data['total_amount']).to eq(expected_total_amount)
      end
    end
  end

  shared_examples 'authentication required' do
    it 'returns HTTP 401' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns error message' do
      expect(response.body).to match_json_schema('error')
    end
  end

  shared_examples 'parameter validation error' do
    it 'returns HTTP 400' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns validation error schema' do
      expect(response.body).to match_json_schema('error')
    end

    it 'includes validation details' do
      expect(JSON.parse(response.body)['message']).to match(/invalid|validation/i)
    end
  end

  shared_examples 'cra uniqueness constraint' do
    it 'returns HTTP 422' do
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns uniqueness error message' do
      expect(JSON.parse(response.body)['message']).to match(/already exists|unique/i)
    end
  end

  shared_examples 'cra not found error' do
    it 'returns HTTP 404' do
      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found error message' do
      expect(JSON.parse(response.body)['message']).to match(/not found|CRA/i)
    end
  end
end

# ============================================================================
# NOTES POUR LES DÉVELOPPEURS
# ============================================================================
#
# Ce template suit les patterns identifiés dans e2e_cra_lifecycle_fc07.sh:
#
# 1. FORMAT DE DATES:
#    - Utiliser format ISO: "2025-01-10"
#    - NE PAS utiliser de formats régionaux
#
# 2. PARSING JSON:
#    - Les réponses utilisent la structure nested: data.entry.*
#    - Parser correctement: data.entry.id, data.entry.line_total
#
# 3. VALIDATION DES RÉPONSES:
#    - Vérifier les schémas avec match_json_schema
#    - Valider les calculs (line_total, totaux CRA)
#
# 4. UUID MANAGEMENT:
#    - Utiliser SecureRandom.uuid pour générer des UUIDs de test
#    - NE PAS convertir les UUIDs en entiers
#
# 5. ERREURS COMMUNES À ÉVITER:
#    - $(date +%m) → utiliser $(date +%-m) pour éviter les zéros de tête
#    - NE PAS mezclar logique métier avec tests de contrat
#    - NE PAS tester les calculs dans les tests de contrat (utiliser business logic specs)
#
# Références:
# - FC-07 Feature Contract
# - e2e_cra_lifecycle_fc07.sh
# - ADR-002: RSwag vs Request Specs Boundary
