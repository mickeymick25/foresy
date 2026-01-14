# frozen_string_literal: true

# Simple Test to Isolate Infrastructure Problems
# This test tries to create basic objects step by step to identify what's causing 500 errors

require 'rails_helper'

RSpec.describe 'Simple CRA Entry Infrastructure Test', type: :request do
  describe 'Basic Object Creation' do
    it 'should be able to create basic objects' do
      puts "\n=== Starting Basic Object Creation Test ==="

      begin
        # Step 1: Create a user
        puts "Step 1: Creating user..."
        user = create(:user)
        puts "✅ User created successfully: #{user.id}"

        # Step 2: Create a company
        puts "Step 2: Creating company..."
        company = create(:company)
        puts "✅ Company created successfully: #{company.id}"

        # Step 3: Create user-company association
        puts "Step 3: Creating user-company association..."
        user_company = create(:user_company, user: user, company: company, role: 'independent')
        puts "✅ User-company association created successfully: #{user_company.id}"

        # Step 4: Create a mission
        puts "Step 4: Creating mission..."
        mission = create(:mission, created_by_user_id: user.id)
        puts "✅ Mission created successfully: #{mission.id}"

        # Step 5: Create mission-company association
        puts "Step 5: Creating mission-company association..."
        mission_company = create(:mission_company, mission: mission, company: company, role: 'independent')
        puts "✅ Mission-company association created successfully: #{mission_company.id}"

        # Step 6: Create a CRA
        puts "Step 6: Creating CRA..."
        cra = create(:cra, user: user)
        puts "✅ CRA created successfully: #{cra.id}"

        # Step 7: Create a CraEntry directly
        puts "Step 7: Creating CraEntry directly..."
        cra_entry = create(:cra_entry)
        puts "✅ CraEntry created successfully: #{cra_entry.id}"

        # Step 8: Create CraEntry-CRA association
        puts "Step 8: Creating CraEntry-CRA association..."
        cra_entry_cra = create(:cra_entry_cra, cra: cra, cra_entry: cra_entry)
        puts "✅ CraEntry-CRA association created successfully: #{cra_entry_cra.id}"

        # Step 9: Create CraEntry-Mission association
        puts "Step 9: Creating CraEntry-Mission association..."
        cra_entry_mission = create(:cra_entry_mission, mission: mission, cra_entry: cra_entry)
        puts "✅ CraEntry-Mission association created successfully: #{cra_entry_mission.id}"

        # Step 10: Test associations
        puts "Step 10: Testing associations..."

        # Test CraEntry associations
        expect(cra_entry.cras).to include(cra)
        expect(cra_entry.missions).to include(mission)
        puts "✅ CraEntry associations working correctly"

        # Test CRA associations
        expect(cra.cra_entries).to include(cra_entry)
        puts "✅ CRA associations working correctly"

        # Test Mission associations
        expect(mission.cra_entries).to include(cra_entry)
        puts "✅ Mission associations working correctly"

        puts "\n🎉 All basic object creation tests PASSED!"

      rescue StandardError => e
        puts "\n❌ FAILED at step: #{e.backtrace.first}"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end

    it 'should be able to make a simple API request' do
      puts "\n=== Starting Simple API Request Test ==="

      begin
        # Create basic setup
        user = create(:user)
        company = create(:company)
        create(:user_company, user: user, company: company, role: 'independent')
        mission = create(:mission, created_by_user_id: user.id)
        create(:mission_company, mission: mission, company: company, role: 'independent')
        cra = create(:cra, user: user)

        # Create user token
        puts "Creating authentication token..."
        user_token = AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token]
        headers = { 'Authorization' => "Bearer #{user_token}", 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
        puts "✅ Authentication token created"

        # Try a simple GET request
        puts "Making simple GET request to CRA entries..."
        get "/api/v1/cras/#{cra.id}/entries", headers: headers

        puts "Response status: #{response.status}"
        puts "Response body: #{response.body}"

        expect(response).to have_http_status(:ok)
        puts "✅ Simple API request successful"

      rescue StandardError => e
        puts "\n❌ FAILED in API request test"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end
  end
end
