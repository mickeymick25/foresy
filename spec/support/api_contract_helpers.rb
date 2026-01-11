# frozen_string_literal: true

module ApiContractHelpers
  extend ActiveSupport::Concern

  # include Devise::Test::ControllerHelpers  # Removed - Devise not used in project

  # ==============================================================================
  # API CONTRACT HELPERS
  # ==============================================================================
  #
  # Ce module contient tous les helpers nécessaires pour les tests de contrat API
  # Il gère l'authentification, les headers, et les setups de test
  #
  # Usage dans les specs :
  #   include ApiContractHelpers
  #   let(:user) { create(:user) }
  #   let(:headers) { authenticated_header(user) }

  # ============================================================================
  # AUTHENTICATION HELPERS
  # ============================================================================

  def authenticated_header(user)
    # Créer une session valide pour l'utilisateur
    sign_in user

    # Générer le token JWT
    token = JsonWebToken.encode(user_id: user.id)

    # Construire le header Authorization
    "Bearer #{token}"
  end

  def invalid_header
    'Bearer invalid_token_12345'
  end

  def expired_header
    # Token expiré (valide mais avec expiration passée)
    expired_time = Time.current - 1.hour
    JsonWebToken.encode(user_id: create(:user).id, exp: expired_time.to_i)
  end

  # ============================================================================
  # TEST USER HELPERS
  # ============================================================================

  def create_test_user(overrides = {})
    user_attributes = {
      email: "test+#{SecureRandom.hex(8)}@example.com",
      password: 'SecurePass123!',
      first_name: 'Test',
      last_name: 'User',
      role: 'independent'
    }.merge(overrides)

    create(:user, user_attributes)
  end

  def create_authenticated_user
    user = create_test_user

    # Créer une session pour cet utilisateur
    session = create(:session, user: user)

    # Générer le token d'authentification
    token = JsonWebToken.encode(
      user_id: user.id,
      session_id: session.id,
      exp: Time.current + 24.hours
    )

    [user, token]
  end

  # ============================================================================
  # CRA TEST SETUP HELPERS
  # ============================================================================

  def cra_setup(user: nil, month: 1, year: 2025)
    user ||= create_test_user

    # Créer une mission pour l'utilisateur
    mission = create(:mission, user: user)

    # Créer un CRA
    cra = create(:cra, user: user, month: month, year: year)

    # Créer quelques entrées CRA
    entries = [
      create(:cra_entry,
             cra: cra,
             mission: mission,
             date: '2025-01-15',
             quantity: 0.5,
             unit_price: 60_000,
             description: 'Morning work'),
      create(:cra_entry,
             cra: cra,
             mission: mission,
             date: '2025-01-20',
             quantity: 1.0,
             unit_price: 80_000,
             description: 'Full day work')
    ]

    cra.reload

    {
      user: user,
      mission: mission,
      cra: cra,
      entries: entries,
      token: authenticated_header(user)
    }
  end

  def create_cra_with_entries(cra_params = {}, entries_params = [])
    cra = create(:cra, cra_params)

    entries_params.each do |entry_params|
      create(:cra_entry, cra: cra, **entry_params)
    end

    cra.reload
    cra
  end

  # ============================================================================
  # MISSION TEST SETUP HELPERS
  # ============================================================================

  def mission_setup(user: nil)
    user ||= create_test_user
    company = create(:company, user: user)

    mission = create(:mission,
                     user: user,
                     client_company: company,
                     name: 'Test Mission',
                     mission_type: 'time_based',
                     daily_rate: 60_000,
                     status: 'won')

    {
      user: user,
      company: company,
      mission: mission,
      token: authenticated_header(user)
    }
  end

  # ============================================================================
  # OAUTH TEST HELPERS
  # ============================================================================

  def mock_oauth_response(provider = :google_oauth2, user_data = {})
    provider_config = {
      provider: provider,
      uid: "12345#{SecureRandom.hex(4)}",
      info: {
        email: "oauth+#{SecureRandom.hex(8)}@example.com",
        first_name: 'OAuth',
        last_name: 'User'
      }.merge(user_data)
    }

    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(provider_config)
  end

  def valid_oauth_callback_params(provider: 'google_oauth2')
    {
      provider: provider,
      code: "valid_auth_code_#{SecureRandom.hex(8)}",
      state: "oauth_state_#{SecureRandom.hex(8)}"
    }
  end

  # ============================================================================
  # RESPONSE VALIDATION HELPERS
  # ============================================================================

  def assert_successful_response(response)
    expect(response).to have_http_status(:success)
    expect(response.content_type).to eq('application/json')
  end

  def assert_error_response(response, status = :unprocessable_entity)
    expect(response).to have_http_status(status)
    expect(response.content_type).to eq('application/json')

    response_data = JSON.parse(response.body)
    expect(response_data).to have_key('error')
    expect(response_data['error']).to have_key('message')
  end

  def assert_cra_response_schema(response)
    expect(response.body).to match_json_schema('cra_response')
  end

  def assert_cra_entry_response_schema(response)
    expect(response.body).to match_json_schema('cra_entry_response')
  end

  def assert_mission_response_schema(response)
    expect(response.body).to match_json_schema('mission_response')
  end

  # ============================================================================
  # PARSING HELPERS
  # ============================================================================

  def parse_json_response(response)
    JSON.parse(response.body)
  end

  def extract_data_from_response(response)
    JSON.parse(response.body)['data']
  end

  def extract_error_from_response(response)
    JSON.parse(response.body)['error']
  end

  def get_cra_from_response(response)
    extract_data_from_response(response)['cra']
  end

  def get_entry_from_response(response)
    extract_data_from_response(response)['entry']
  end

  # ============================================================================
  # UUID HELPERS
  # ============================================================================

  def generate_test_uuid
    SecureRandom.uuid
  end

  def create_existing_cra_id
    create(:cra).id
  end

  def create_existing_mission_id
    create(:mission).id
  end

  def nonexistent_uuid
    '00000000-0000-0000-0000-000000000000'
  end

  # ============================================================================
  # RATE LIMITING HELPERS
  # ============================================================================

  def make_authenticated_request(endpoint, headers, times: 1)
    times.times do
      get endpoint, headers: { 'Authorization' => headers }
    end
  end

  def assert_rate_limited(response)
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['X-RateLimit-Remaining']).to eq('0')
  end

  # ============================================================================
  # FILE UPLOAD HELPERS (pour futures features)
  # ============================================================================

  def uploaded_file(filename:, content_type: 'text/plain', content: 'test content')
    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      filename,
      content_type: content_type,
      binary: false
    )
  end

  # ============================================================================
  # CLEANUP HELPERS
  # ============================================================================

  def cleanup_test_data
    # Nettoyer les données de test après chaque spec
    DatabaseCleaner.clean
  end

  def reset_omniauth_config
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  # ============================================================================
  # VALIDATION HELPERS POUR SCHEMAS
  # ============================================================================

  def validate_swagger_schema(response, schema_name)
    expect(response.body).to match_json_schema(schema_name)
  end

  def assert_required_fields_present(response, required_fields)
    response_data = parse_json_response(response)

    required_fields.each do |field|
      expect(response_data).to have_key(field), "Required field '#{field}' is missing"
    end
  end

  # ============================================================================
  # CLASS METHODS FOR MODULE INCLUSION
  # ============================================================================

  class_methods do
    def it_behaves_like_authenticated_endpoint
      context 'when not authenticated' do
        let(:headers) { {} }

        it 'returns 401 Unauthorized' do
          subject.call
          expect(response).to have_http_status(:unauthorized)
        end

        it 'returns error message' do
          subject.call
          expect(response.body).to match_json_schema('error')
        end
      end
    end

    def it_behaves_like_rate_limited_endpoint
      context 'when rate limited' do
        let(:headers) { authenticated_header(create_test_user) }

        before do
          # Simuler le rate limiting en dépassant la limite
          6.times do |i|
            get described_class.send(:action_path),
                headers: { 'Authorization' => headers },
                params: { request_number: i + 1 }
          end
        end

        it 'returns 429 Too Many Requests' do
          get described_class.send(:action_path),
              headers: { 'Authorization' => headers }
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    def it_behaves_like_validates_required_params(required_params)
      context 'with missing required parameters' do
        required_params.each do |param|
          context "missing #{param}" do
            let(:body) do
              valid_body = {
                month: 1,
                year: 2025,
                currency: 'EUR'
              }
              valid_body.delete(param)
              valid_body
            end

            it 'returns 400 Bad Request' do
              subject.call
              expect(response).to have_http_status(:bad_request)
            end

            it 'returns validation error' do
              subject.call
              expect(response.body).to match_json_schema('error')
            end
          end
        end
      end
    end
  end
end

# ============================================================================
# NOTES POUR LES DÉVELOPPEURS
# ============================================================================
#
# Ce module fournit tous les helpers nécessaires pour les tests de contrat API :
#
# 1. AUTHENTIFICATION:
#    - authenticated_header(user) : Header Authorization valide
#    - invalid_header() : Header invalide pour tests d'erreur
#    - expired_header() : Token expiré
#
# 2. SETUP DE TESTS:
#    - cra_setup() : Setup complet pour tests CRA
#    - mission_setup() : Setup pour tests missions
#    - create_test_user() : Utilisateur de test avec données valides
#
# 3. VALIDATION:
#    - assert_successful_response() : Vérifie réponse 200
#    - assert_error_response() : Vérifie réponse d'erreur
#    - validate_swagger_schema() : Valide le schéma Swagger
#
# 4. PARSING:
#    - parse_json_response() : Parse la réponse JSON
#    - extract_data_from_response() : Extrait la clé 'data'
#    - get_cra_from_response() : Extrait le CRA de la réponse
#
# 5. OAUTH:
#    - mock_oauth_response() : Mock pour tests OAuth
#    - valid_oauth_callback_params() : Paramètres OAuth valides
#
# 6. SHARED EXAMPLES:
#    - it_behaves_like_authenticated_endpoint
#    - it_behaves_like_rate_limited_endpoint
#    - it_behaves_like_validates_required_params
#
# Usage dans les specs :
#   RSpec.describe "API Contract Tests", type: :rswag do
#     include ApiContractHelpers
#
#     let(:user) { create_test_user }
#     let(:headers) { authenticated_header(user) }
#
#     it_behaves_like 'authenticated endpoint'
#   end
#
# Références:
# - FC-07 CRA Feature Contract
# - Template api_contract_spec_template.rb
# - Swagger schema validation</parameter>
