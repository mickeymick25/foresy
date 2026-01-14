# frozen_string_literal: true

# Direct ListService Test to Identify Exact Error
# This test calls CraEntries::ListService directly to isolate the exact error

require 'rails_helper'

RSpec.describe 'Direct CraEntries::ListService Test', type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:mission) { create(:mission, created_by_user_id: user.id) }
  let(:cra) { create(:cra, user: user) }
  let(:cra_entry) { create(:cra_entry) }

  before do
    # Create required associations for testing
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
    create(:cra_entry_cra, cra: cra, cra_entry: cra_entry)
    create(:cra_entry_mission, mission: mission, cra_entry: cra_entry)
  end

  describe 'Direct ListService Call' do
    it 'should call CraEntries::ListService directly and succeed' do
      puts "\n=== Testing CraEntries::ListService Directly ==="

      begin
        puts "Setup complete:"
        puts "  User: #{user.id}"
        puts "  CRA: #{cra.id}"
        puts "  CraEntry: #{cra_entry.id}"

        puts "\nCalling Api::V1::CraEntries::ListService.call..."

        # Call the service directly with correct namespace
        result = Api::V1::CraEntries::ListService.call(
          cra: cra,
          include_associations: true
        )

        puts "✅ ListService call successful!"
        puts "Result class: #{result.class}"
        puts "Result success?: #{result.success?}"
        puts "Result value?: #{result.value?}"

        if result.respond_to?(:value)
          puts "Result value: #{result.value.inspect}"
        end

        expect(result).to be_present
        expect(result.success?).to be true

      rescue StandardError => e
        puts "❌ ListService call failed!"
        puts "Error class: #{e.class}"
        puts "Error message: #{e.message}"
        puts "Error backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end

    it 'should test CraEntries::ListService without associations' do
      puts "\n=== Testing ListService without associations ==="

      begin
        puts "Calling ListService with include_associations: false..."

        result = Api::V1::CraEntries::ListService.call(
          cra: cra,
          include_associations: false
        )

        puts "✅ ListService (no associations) call successful!"
        puts "Result success?: #{result.success?}"

        expect(result).to be_present
        expect(result.success?).to be true

      rescue StandardError => e
        puts "❌ ListService (no associations) call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end

    it 'should check if CraEntries::ListService class exists' do
      puts "\n=== Checking ListService Class Existence ==="

      begin
        puts "Checking if Api::V1::CraEntries::ListService class exists..."

        service_class = Api::V1::CraEntries::ListService
        puts "✅ ListService class found: #{service_class}"
        puts "Class ancestors: #{service_class.ancestors.inspect}"
        puts "Class methods: #{service_class.methods(false).inspect}"

        # Check if call method exists
        if service_class.respond_to?(:call)
          puts "✅ ListService.call method exists"
        else
          puts "❌ ListService.call method does NOT exist"
          puts "Available methods: #{service_class.methods(false).inspect}"
        end

      rescue NameError => e
        puts "❌ Api::V1::CraEntries::ListService class does NOT exist!"
        puts "Error: #{e.class} - #{e.message}"
        puts "This means the ListService file is not being loaded properly"
        raise e
      rescue StandardError => e
        puts "❌ Unexpected error checking ListService class!"
        puts "Error: #{e.class} - #{e.message}"
        raise e
      end
    end

    it 'should test ListService with invalid CRA' do
      puts "\n=== Testing ListService with invalid CRA ==="

      begin
        puts "Calling ListService with nil CRA..."

        result = Api::V1::CraEntries::ListService.call(
          cra: nil,
          include_associations: true
        )

        puts "Result with nil CRA:"
        puts "  success?: #{result.success?}"

        # This should fail, so we expect success? to be false
        expect(result.success?).to be false

      rescue StandardError => e
        puts "ListService with nil CRA raised exception (expected):"
        puts "Error: #{e.class} - #{e.message}"
        # This is expected behavior
      end
    end
  end
end
