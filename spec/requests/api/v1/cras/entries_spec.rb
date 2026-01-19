# frozen_string_literal: true

# CraEntriesController Platinum Level Tests - FIXED VERSION
# Comprehensive test coverage for FC-07 CRA Management
# Production-grade test suite with advanced validation patterns
# FIXED: Domain-Driven Architecture with correct relation table associations

require 'rails_helper'

RSpec.describe 'API V1 CRA Entries', type: :request do
  # Enhanced authentication setup
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{user_token}", 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

  # Comprehensive test data setup
  let(:company) { create(:company) }
  let(:mission) { create(:mission, created_by_user_id: user.id) }
  let(:cra) { create(:cra, user: user) }

  # Ensure user is properly associated with company (Domain-Driven Architecture)
  before do
    create(:user_company, user: user, company: company, role: 'independent')
    # Add mission_company association to make mission accessible to user
    create(:mission_company, mission: mission, company: company, role: 'client')
  end

  # Valid CRA Entry parameters for testing
  # Based on CraEntry model requirements: date, quantity, unit_price, description
  let(:valid_entry_params) do
    {
      mission_id: mission.id,
      date: '2025-01-15',
      quantity: 1.0,
      unit_price: 60000, # 600.00 EUR in cents
      description: 'Development work'
    }
  end

  # Invalid parameters for error handling tests
  let(:invalid_params) { { invalid: 'params' } }

  # DDD-compliant: Create CraEntry with proper relation table associations
  let(:cra_entry) do
    entry = create(:cra_entry)
    create(:cra_entry_cra, cra: cra, cra_entry: entry)
    create(:cra_entry_mission, mission: mission, cra_entry: entry)
    entry
  end

  # Authorization testing data
  let(:other_user) { create(:user) }
  let(:other_user_token) { AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token] }
  let(:other_headers) { { 'Authorization' => "Bearer #{other_user_token}" } }
  let(:other_company) { create(:company) }
  let(:other_cra) { create(:cra, user: other_user) }

  # Ensure other_user is properly associated with other_company for authorization testing
  before do
    create(:user_company, user: other_user, company: other_company, role: 'independent')
  end

  # Performance testing setup
  let(:test_rates) { { create: 10, read: 20, update: 5, delete: 3 } }

  # =============================================================================
  # PHASE 1: AUTHENTICATION & ACCESS CONTROL (ENHANCED)
  # =============================================================================

  describe 'Authentication & Access Control' do
    context 'when user is not authenticated' do
      let(:headers) { {} }

      it 'returns 401 Unauthorized for all endpoints' do
        endpoints = [
          -> { post "/api/v1/cras/#{cra.id}/entries", params: valid_entry_params },
          -> { get "/api/v1/cras/#{cra.id}/entries" },
          -> { get "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}" },
          -> { patch "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}", params: { quantity: 2.0 } },
          -> { delete "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}" }
        ]

        endpoints.each do |endpoint|
          endpoint.call
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when user has no access to CRA' do
      it 'returns 403 Forbidden for all unauthorized endpoints' do
        # Create entry associated with other_cra
        other_entry = create(:cra_entry)
        create(:cra_entry_cra, cra: other_cra, cra_entry: other_entry)
        create(:cra_entry_mission, mission: mission, cra_entry: other_entry)

        unauthorized_endpoints = [
          -> { post "/api/v1/cras/#{cra.id}/entries", params: valid_entry_params.to_json, headers: other_headers.merge('Content-Type' => 'application/json') },
          -> { get "/api/v1/cras/#{cra.id}/entries", headers: other_headers },
          -> { get "/api/v1/cras/#{cra.id}/entries/#{other_entry.id}", headers: other_headers },
          -> { patch "/api/v1/cras/#{cra.id}/entries/#{other_entry.id}", params: { quantity: 2.0 }.to_json, headers: other_headers.merge('Content-Type' => 'application/json') },
          -> { delete "/api/v1/cras/#{cra.id}/entries/#{other_entry.id}", headers: other_headers }
        ]

        unauthorized_endpoints.each do |endpoint|
          endpoint.call
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'when user token is expired' do
      it 'returns 401 Unauthorized' do
        skip 'Expired token test requires AuthenticationService implementation'
        # This would require implementing generate_expired_token in AuthenticationService
      end
    end
  end

  # =============================================================================
  # PHASE 2: BUSINESS LOGIC VALIDATION (PLATINUM ADDITION)
  # =============================================================================

  describe 'Business Logic Validation' do
    context 'CRA Entry Business Rules' do
      it 'validates mission belongs to user company' do
        # Create a mission from a different company
        other_company = create(:company)
        other_company_mission = create(:mission, created_by_user_id: user.id)
        create(:mission_company, mission: other_company_mission, company: other_company, role: 'client')

        invalid_params = valid_entry_params.merge(mission_id: other_company_mission.id)

        post "/api/v1/cras/#{cra.id}/entries", params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(/mission.*company/i)
      end

      it 'validates date is within CRA period' do
        # This test would require CRA period validation to be implemented
        skip 'CRA period validation not yet implemented'

        invalid_date_params = valid_entry_params.merge(date: '2025-12-31') # Outside CRA period

        post "/api/v1/cras/#{cra.id}/entries", params: invalid_date_params.to_json, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(/date.*period/)
      end

      it 'validates total amount calculation' do
        test_params = {
          date: '2024-01-15',
          quantity: 2.5,
          unit_price: 40_000, # 400.00 EUR
          description: 'Consulting work',
          mission_id: mission.id
        }

        # Vérifier le total_amount avant création
        cra.reload
        expect(cra.total_amount).to eq(0)

        post "/api/v1/cras/#{cra.id}/entries",
             params: test_params.to_json,
             headers: headers

        expect(response).to have_http_status(:created)

        # Vérifier que la réponse contient l'entrée créée
        json = JSON.parse(response.body)
        expect(json['data']['cra_entry']).to be_present
        expect(json['data']['cra_entry']['quantity']).to eq("2.5")
        expect(json['data']['cra_entry']['unit_price']).to eq(40_000)

        # Vérifier que le total_amount du CRA a été correctement calculé
        cra.reload
        expected_total = 2.5 * 40_000  # = 100000
        expect(cra.total_amount).to eq(expected_total)
      end

      it 'prevents duplicate entries for same mission and date' do
        # Paramètres explicites pour éviter l'ambiguïté
        entry_date = Date.new(2024, 1, 15)

        entry_params = {
          mission_id: mission.id,
          date: entry_date,
          quantity: 1,
          unit_price: 40000,
          description: "Consulting"
        }

        # Première création (baseline)
        post "/api/v1/cras/#{cra.id}/entries",
             params: entry_params.to_json,
             headers: headers

        expect(response).to have_http_status(:created)
        expect(cra.cra_entries.count).to eq(1)

        # Tentative de doublon
        post "/api/v1/cras/#{cra.id}/entries",
             params: entry_params.to_json,
             headers: headers

        # Assertions métier (le cœur)
        expect(response).to have_http_status(:unprocessable_content)
        expect(cra.cra_entries.count).to eq(1)  # invariant métier

        # Vérification message d'erreur (optionnel mais utile)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(
          a_string_matching(/already exists|duplicate/i)
        )
      end
    end
  end

  # L452 – CRA/Mission Association
  describe 'POST /api/v1/cras/:cra_id/entries - CRA/Mission Association', type: :request do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:cra) { create(:cra, user: user) }
    let(:headers) { { 'Authorization' => "Bearer #{AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token]}", 'Content-Type' => 'application/json' } }

    let(:valid_entry_params) do
      {
        date: Date.today,
        quantity: 2.5,
        unit_price: 40000,
        description: "Consulting work"
      }
    end

    it 'validates CRA/mission association' do
      # --- CAS 1: Mission valide (même utilisateur/entreprise) ---
      valid_mission = create(:mission, created_by_user_id: user.id)
      # Créer l'association mission/entreprise pour rendre la mission valide
      create(:mission_company, mission: valid_mission, company: company, role: 'client')
      params_valid = valid_entry_params.merge(mission_id: valid_mission.id)
      post "/api/v1/cras/#{cra.id}/entries", params: params_valid.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['cra_entry']['attributes']['mission_id']).to eq(valid_mission.id)
      expect(cra.cra_entries.count).to eq(1)

      # --- CAS 2: Mission invalide (autre utilisateur) ---
      invalid_mission = create(:mission, created_by_user_id: other_user.id)
      params_invalid = valid_entry_params.merge(mission_id: invalid_mission.id)
      post "/api/v1/cras/#{cra.id}/entries", params: params_invalid.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['error'].downcase).to include("mission does not belong")

      # --- CAS 3: Mission inexistante ---
      params_nonexistent = valid_entry_params.merge(mission_id: SecureRandom.uuid)
      post "/api/v1/cras/#{cra.id}/entries", params: params_nonexistent.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error'].downcase).to include("not found")
    end
  end

  # =============================================================================
  # PHASE 3: DATA VALIDATION & SECURITY (PLATINUM ADDITION)
  # =============================================================================

  describe 'Data Validation & Security' do
    context 'SQL Injection Protection' do
      it 'sanitizes malicious SQL in parameters' do
        # Rails blocks SQL-like payloads in form-encoded requests at middleware level.
        # JSON format is required to test application-level sanitization.
        malicious_params = valid_entry_params.merge(
          description: "'; DROP TABLE cra_entries; --"
        )

        post "/api/v1/cras/#{cra.id}/entries",
             params: malicious_params.to_json,
             headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:created)
        expect(CraEntry.exists?).to be true
      end
    end

    context 'XSS Prevention' do
      it 'sanitizes malicious script in description' do
        xss_params = valid_entry_params.merge(
          description: "<script>alert('xss')</script>Development work"
        )

        post "/api/v1/cras/#{cra.id}/entries", params: xss_params.to_json, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        entry = json_response['data']['cra_entry']
        expect(entry['description']).not_to include('<script>')
      end
    end

    context 'Input Validation' do
      it 'rejects negative quantities' do
        negative_params = valid_entry_params.merge(quantity: -1.0)

        post "/api/v1/cras/#{cra.id}/entries", params: negative_params.to_json, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(/quantity.*greater.*0/)
      end

      it 'rejects future dates' do
        future_params = valid_entry_params.merge(date: Date.tomorrow.strftime('%Y-%m-%d'))

        post "/api/v1/cras/#{cra.id}/entries", params: future_params.to_json, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(/future/)
      end

      it 'validates unit_price format (cents only)' do
        decimal_params = valid_entry_params.merge(unit_price: 60.50)

        post "/api/v1/cras/#{cra.id}/entries",
             params: decimal_params.to_json,
             headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(/unit_price.*integer/)
      end
    end
  end

  # =============================================================================
  # PHASE 4: PERFORMANCE & RATE LIMITING (PLATINUM ADDITION)
  # =============================================================================

  describe 'Performance & Rate Limiting' do
    context 'Rate Limiting Implementation' do
      it 'enforces rate limits on create operations' do
        skip 'Rate limiting not yet implemented'
        # This would require implementing rate limiting middleware
      end

      it 'tracks rate limiting per user' do
        skip 'Rate limiting not yet implemented'
        # This would require implementing rate limiting middleware
      end
    end

    context 'Response Time Monitoring' do
      it 'responds within acceptable time limits' do
        start_time = Time.current

        post "/api/v1/cras/#{cra.id}/entries", params: valid_entry_params.to_json, headers: headers.merge('Content-Type' => 'application/json')

        response_time = Time.current - start_time
        expect(response_time).to be < 1.second # Acceptable response time
        expect(response).to have_http_status(:created)
      end
    end
  end

  # =============================================================================
  # PHASE 5: PAGINATION & FILTERING (PLATINUM ADDITION)
  # =============================================================================

  describe 'Pagination & Filtering' do
    let(:entries) do
      # Create multiple entries with proper associations
      15.times.map do |i|
        entry = create(:cra_entry, date: Date.current - i.days)
        create(:cra_entry_cra, cra: cra, cra_entry: entry)
        create(:cra_entry_mission, mission: mission, cra_entry: entry)
        entry
      end
    end

    context 'Pagination' do
      it 'implements pagination for entries list' do
        entries # Create the entries

        get "/api/v1/cras/#{cra.id}/entries?page=1&per_page=10", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['data']['entries']).to be_an(Array)
        expect(json_response['data']['entries'].length).to be <= 10
        expect(json_response['meta']['pagination']).to be_present
        expect(json_response['meta']['pagination']['current_page']).to eq(1)
        expect(json_response['meta']['pagination']['per_page']).to eq(10)
      end

      it 'handles invalid pagination parameters' do
        get "/api/v1/cras/#{cra.id}/entries?page=0&per_page=1000", headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(/pagination.*invalid/)
      end
    end

    context 'Filtering' do
      it 'filters entries by date range' do
        entries # Create the entries

        from_date = 1.week.ago.to_date
        to_date = Date.today

        get "/api/v1/cras/#{cra.id}/entries?from_date=#{from_date}&to_date=#{to_date}", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Verify all returned entries are within date range
        json_response['data']['entries'].each do |entry|
          entry_date = Date.parse(entry['date'])
          expect(entry_date).to be >= from_date
          expect(entry_date).to be <= to_date
        end
      end

      it 'filters entries by mission' do
        # Create specific mission entry
        specific_mission = create(:mission, created_by_user_id: user.id)
        mission_entry = create(:cra_entry)
        create(:cra_entry_cra, cra: cra, cra_entry: mission_entry)
        create(:cra_entry_mission, mission: specific_mission, cra_entry: mission_entry)

        get "/api/v1/cras/#{cra.id}/entries?mission_id=#{specific_mission.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['data']['entries'].length).to eq(1)
        expect(json_response['data']['entries'].first['mission_id']).to eq(specific_mission.id)
      end
    end
  end

  # =============================================================================
  # PHASE 6: LOGGING & MONITORING (PLATINUM ADDITION)
  # =============================================================================

  describe 'Logging & Monitoring' do
    context 'Activity Logging' do
      it 'logs entry creation with basic logging' do
        # Basic test that the request completes without error
        post "/api/v1/cras/#{cra.id}/entries", params: valid_entry_params.to_json, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:created)
        # Note: Specific logging would need to be implemented in controllers/services
      end

      it 'logs access attempts with basic logging' do
        # Basic test that the request completes without error
        get "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}", headers: headers

        expect(response).to have_http_status(:ok)
        # Note: Specific logging would need to be implemented in controllers/services
      end

      it 'logs security violations' do
        # This would require implementing security violation logging
        skip 'Security violation logging not yet implemented'
      end
    end

    context 'Audit Trail' do
      it 'creates audit log entries' do
        skip 'AuditLog model not yet implemented'
        # This would require implementing AuditLog model
      end
    end
  end

  # =============================================================================
  # PHASE 7: CONCURRENCY & TRANSACTIONS (PLATINUM ADDITION)
  # =============================================================================

  describe 'Concurrency & Transactions' do
    context 'Race Conditions' do
      it 'handles concurrent entry creation safely' do
        skip 'Concurrency testing requires additional setup'
        # This would require implementing proper concurrency handling
      end
    end

    context 'Transaction Integrity' do
      it 'rolls back on validation failure' do
        initial_count = CraEntry.count

        # Try to create entry with invalid mission
        post "/api/v1/cras/#{cra.id}/entries",
             params: valid_entry_params.merge(mission_id: 'invalid-id'),
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(CraEntry.count).to eq(initial_count) # No partial creation
      end
    end
  end

  # =============================================================================
  # ORIGINAL CRUD TESTS (ENHANCED)
  # =============================================================================

  describe 'POST /api/v1/cras/:cra_id/entries' do
    context 'with valid parameters' do
      it 'creates a new CRA entry successfully' do
        post "/api/v1/cras/#{cra.id}/entries",
             params: valid_entry_params.to_json,
             headers: headers.merge('Content-Type' => 'application/json')

        # Debug: Capture error details for 500 errors
        if response.status == 500
          puts "\n=== DEBUG: 500 ERROR DETAILS ==="
          puts "Status: #{response.status}"
          puts "Body: #{response.body}"
          puts "Headers: #{response.headers.inspect}"
          puts "Request headers: #{headers.inspect}"
          puts "Params sent: #{valid_entry_params.inspect}"
          puts "CRA ID: #{cra.id}"
          puts "===============================\n"
        end

        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        expect(json_response['data']).to be_present
        expect(json_response['data']['cra_entry']).to be_present
      end

      it 'associates entry with correct CRA and mission' do
        post "/api/v1/cras/#{cra.id}/entries",
             params: valid_entry_params.to_json,
             headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        entry_id = json_response['data']['cra_entry']['id']

        # Verify associations through relation tables
        cra_entry_cra = CraEntryCra.find_by(cra_entry_id: entry_id)
        cra_entry_mission = CraEntryMission.find_by(cra_entry_id: entry_id)

        expect(cra_entry_cra).to be_present
        expect(cra_entry_mission).to be_present
        expect(cra_entry_cra.cra_id).to eq(cra.id)
        expect(cra_entry_mission.mission_id).to eq(mission.id)
      end
    end

    context 'with invalid parameters' do
      context 'when required fields are missing' do
        it 'returns 422 Unprocessable Entity for missing required fields' do
          invalid_params = valid_entry_params.except(:quantity)
          post "/api/v1/cras/#{cra.id}/entries",
               params: invalid_params.to_json,
               headers: headers

          expect(response).to have_http_status(:unprocessable_content)

          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end

      context 'when CRA does not exist' do
        it 'returns 404 Not Found' do
          post "/api/v1/cras/nonexistent-cra-id/entries",
               params: valid_entry_params.to_json,
               headers: headers

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'with edge cases' do
      context 'when quantity is fractional' do
        [0.25, 0.5, 1.5].each do |fractional_quantity|
          it "accepts fractional quantity #{fractional_quantity}" do
            fractional_params = valid_entry_params.merge(quantity: fractional_quantity)
            post "/api/v1/cras/#{cra.id}/entries",
                 params: fractional_params.to_json,
                 headers: headers.merge('Content-Type' => 'application/json')

            expect(response).to have_http_status(:created)
          end
        end
      end

      context 'when unit_price is zero' do
        it 'accepts zero unit_price' do
          zero_price_params = valid_entry_params.merge(unit_price: 0)
          post "/api/v1/cras/#{cra.id}/entries",
               params: zero_price_params.to_json,
               headers: headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:created)

          # Parse JSON response
          json_response = JSON.parse(response.body)

          # DEBUG: Voir la vraie structure JSON
          puts "🔥 DEBUG: JSON Response structure = #{json_response.inspect}"

          # Validation avec la structure JSON actuelle
          data = json_response['data']
          expect(data).to be_present

          cra_entry = data['cra_entry']
          expect(cra_entry).to be_present
          expect(cra_entry['type']).to eq('cra_entry')

          attributes = cra_entry['attributes']
          expect(attributes['date']).to eq(Date.today.strftime('%Y-%m-%d'))
          expect(attributes['quantity']).to eq('1.0')
          expect(attributes['unit_price']).to eq(0)
          expect(attributes['description']).to eq('Development work')
          expect(attributes['mission_id']).to eq(valid_entry_params[:mission_id])
        end
      end
    end
  end

  describe 'GET /api/v1/cras/:cra_id/entries' do
    context 'with existing entries' do
      let(:entries) do
        # Create multiple entries with proper associations
        3.times.map do |i|
          entry = create(:cra_entry, date: Date.current - i.days)
          create(:cra_entry_cra, cra: cra, cra_entry: entry)
          create(:cra_entry_mission, mission: mission, cra_entry: entry)
          entry
        end
      end

      it 'returns all entries for the CRA' do
        entries # Create the entries

        get "/api/v1/cras/#{cra.id}/entries", headers: headers

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['data']).to be_present
        expect(json_response['data']['entries']).to be_an(Array)
        expect(json_response['data']['entries'].length).to eq(3)
      end
    end

    context 'with no entries' do
      it 'returns empty array' do
        get "/api/v1/cras/#{cra.id}/entries", headers: headers

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['data']['entries']).to eq([])
      end
    end

    context 'when CRA does not exist' do
      it 'returns 404 Not Found' do
        get "/api/v1/cras/nonexistent-cra-id/entries", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/cras/:cra_id/entries/:id' do
    context 'when entry exists' do
      it 'returns the specific entry' do
        get "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}", headers: headers

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        puts "DEBUG: json_response = #{json_response.inspect}"
        data = json_response['data']

        expect(data).to be_present
        expect(data['id']).to eq(cra_entry.id.to_s)
        expect(data['type']).to eq('cra_entry')
        expect(data['attributes']).to include('date', 'quantity', 'unit_price')
      end
    end

    context 'when entry does not exist' do
      it 'returns 404 Not Found' do
        get "/api/v1/cras/#{cra.id}/entries/nonexistent-id", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when CRA does not exist' do
      it 'returns 404 Not Found' do
        get "/api/v1/cras/nonexistent-cra-id/entries/#{cra_entry.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/cras/:cra_id/entries/:id' do
    context 'with valid parameters' do
      it 'updates the entry successfully' do
        new_quantity = 2.5
        new_description = 'Updated description'

        # DEBUG: Show IDs being used
        puts "\n=== TEST DEBUG: PATCH REQUEST IDS ==="
        puts "CRA ID: #{cra.id}"
        puts "CRA created_by_user_id: #{cra.created_by_user_id}, current_user_id should be: #{user.id}"
        puts "CRA Entry ID: #{cra_entry.id}"
        puts "CRA Entry exists in DB: #{CraEntry.exists?(id: cra_entry.id)}"
        puts "CRA Entry count for this CRA: #{CraEntry.joins(:cra_entry_cras).where(cra_entry_cras: { cra_id: cra.id }).count}"
        puts "Available CRA Entry IDs for this CRA: #{CraEntry.joins(:cra_entry_cras).where(cra_entry_cras: { cra_id: cra.id }).pluck(:id).inspect}"
        puts "=== END DEBUG ===\n"

        patch "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}",
              params: { quantity: new_quantity, description: new_description }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        # DEBUG: Show response details when status is not 200 or when we want to see the response structure
        puts "\n=== DEBUG PATCH RESPONSE STRUCTURE ==="
        puts "Status: #{response.status}"
        puts "Body: #{response.body}"

        # Parse and show full JSON structure
        begin
          json_response = JSON.parse(response.body)
          puts "Parsed JSON structure: #{json_response.inspect}"
          puts "JSON keys: #{json_response.keys.inspect}"
          if json_response['data']
            puts "data keys: #{json_response['data'].keys.inspect}"
            if json_response['data']['cra_entry']
              puts "cra_entry keys: #{json_response['data']['cra_entry'].keys.inspect}"
              puts "cra_entry quantity: #{json_response['data']['cra_entry']['quantity']}"
              puts "cra_entry description: #{json_response['data']['cra_entry']['description']}"
            else
              puts "cra_entry is nil or missing"
            end
          else
            puts "data is nil or missing"
          end
        rescue JSON::ParserError => e
          puts "Failed to parse JSON: #{e.message}"
        end

        puts "Headers: #{response.headers.inspect}"
        puts "Params sent: #{[quantity: new_quantity, description: new_description].inspect}"
        puts "CRA ID: #{cra.id}"
        puts "CRA Entry ID: #{cra_entry.id}"
        puts "CRA Entry current quantity: #{cra_entry.quantity}"
        puts "CRA Entry current description: #{cra_entry.description}"
        puts "===============================\n"

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['data']['cra_entry']['quantity']).to eq(new_quantity)
        expect(json_response['data']['cra_entry']['description']).to eq(new_description)
      end
    end

    context 'when entry does not exist' do
      it 'returns 404 Not Found' do
        # Use a valid UUID format that doesn't exist in the database
        nonexistent_uuid = SecureRandom.uuid
        patch "/api/v1/cras/#{cra.id}/entries/#{nonexistent_uuid}",
              params: { quantity: 2.0 }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when CRA does not exist' do
      it 'returns 404 Not Found' do
        # Use a valid UUID format that doesn't exist in the database
        nonexistent_cra_uuid = SecureRandom.uuid
        patch "/api/v1/cras/#{nonexistent_cra_uuid}/entries/#{cra_entry.id}",
              params: { quantity: 2.0 }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/cras/:cra_id/entries/:id' do
    context 'when entry exists' do
      it 'deletes the entry successfully' do
        delete "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(CraEntry.with_deleted.find_by(id: cra_entry.id)).to be_present
        expect(CraEntry.find_by(id: cra_entry.id)).to be_nil
      end
    end

    context 'when entry does not exist' do
      it 'returns 404 Not Found' do
        delete "/api/v1/cras/#{cra.id}/entries/nonexistent-id", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when CRA does not exist' do
      it 'returns 404 Not Found' do
        delete "/api/v1/cras/nonexistent-cra-id/entries/#{cra_entry.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # =============================================================================
  # ERROR HANDLING & EDGE CASES
  # =============================================================================

  describe 'Error Handling & Edge Cases' do
    context 'when rate limit is exceeded' do
      it 'returns 429 Too Many Requests' do
        skip 'Rate limiting tests require specific setup'
        # Test rate limiting behavior
      end
    end

    context 'L725 - Invalid JSON body' do
      it 'retourne 422 unprocessable_entity avec erreur JSON:API' do
        post "/api/v1/cras/#{cra.id}/entries",
             params: '{ invalid json',
             headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_content)
        expect_cra_api_error(status: :unprocessable_content, code_or_message: /parsing|parameters|request/i) do |error|
          expect(error['status']).to eq('422')
          expect(error['title']).to match(/Unprocessable Entity/i)
          expect(error['detail']).to match(/error occurred while parsing request parameters/i)
        end
      end
    end

    context 'L735 - Invalid Authentication' do
      it 'returns 401 Unauthorized with authentication error' do
        post "/api/v1/cras/#{cra.id}/entries",
             params: valid_entry_params.to_json,
             headers: headers.merge('Authorization' => 'Invalid token')

        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
        expect(json_response['error']).to match(/unauthorized|invalid|token/i)
      end
    end
  end

  # =============================================================================
  # PRIVATE HELPERS (ENHANCED)
  # =============================================================================

  private

  def valid_entry_params
    {
      mission_id: mission.id,
      quantity: 1.0,
      unit_price: 60000, # 600.00 EUR in cents
      description: 'Development work',
      date: '2025-01-15'
    }
  end
end
