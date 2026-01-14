# frozen_string_literal: true

# Direct Service Test to Identify 500 Error Cause
# This test calls CraEntries services directly to isolate the exact error

require 'rails_helper'

RSpec.describe 'Direct CraEntries Service Test', type: :request do
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

  describe 'Direct Service Calls' do
    it 'should call CraEntries::ListService directly' do
      puts "\n=== Testing CraEntries::ListService ==="

      begin
        puts "Calling CraEntries::ListService.call..."
        result = CraEntries::ListService.call(cra: cra, include_associations: true)

        puts "✅ ListService call successful!"
        puts "Result: #{result.inspect}"
        puts "Result success?: #{result.success?}"
        puts "Result value: #{result.value?.inspect}"

        expect(result.success?).to be true

      rescue StandardError => e
        puts "❌ ListService call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end

    it 'should call CraEntries::CreateService directly' do
      puts "\n=== Testing CraEntries::CreateService ==="

      begin
        entry_params = {
          date: Date.current.strftime('%Y-%m-%d'),
          quantity: 1.0,
          unit_price: 60000,
          description: 'Test entry'
        }

        puts "Calling CraEntries::CreateService.call..."
        result = CraEntries::CreateService.call(
          cra: cra,
          entry_params: entry_params,
          mission_id: mission.id,
          current_user: user
        )

        puts "✅ CreateService call successful!"
        puts "Result: #{result.inspect}"
        puts "Result entry: #{result.entry.inspect}"

        expect(result.success?).to be true

      rescue StandardError => e
        puts "❌ CreateService call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end

    it 'should call CraEntries::ShowService directly' do
      puts "\n=== Testing CraEntries::ShowService ==="

      begin
        puts "Calling CraEntries::ShowService.call..."
        result = CraEntries::ShowService.call(entry: cra_entry, cra: cra)

        puts "✅ ShowService call successful!"
        puts "Result: #{result.inspect}"

        expect(result.success?).to be true

      rescue StandardError => e
        puts "❌ ShowService call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    rescue LoadError, NameError => e
      puts "❌ ShowService does not exist!"
      puts "Error: #{e.class} - #{e.message}"
      puts "This might be the source of the 500 errors - missing service!"
      raise e
    end

    it 'should check CraEntries::UpdateService existence' do
      puts "\n=== Testing CraEntries::UpdateService ==="

      begin
        puts "Checking if UpdateService exists..."

        # Try to access the service class
        service_class = CraEntries::UpdateService
        puts "✅ UpdateService class exists: #{service_class}"

        # Try to call it with minimal parameters
        puts "Calling UpdateService with minimal parameters..."
        result = service_class.call(
          entry: cra_entry,
          entry_params: { description: 'Updated test' },
          mission_id: mission.id,
          current_user: user
        )

        puts "✅ UpdateService call successful!"
        puts "Result: #{result.inspect}"

      rescue StandardError => e
        puts "❌ UpdateService call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    rescue LoadError, NameError => e
      puts "❌ UpdateService does not exist!"
      puts "Error: #{e.class} - #{e.message}"
      puts "This might be the source of the 500 errors - missing service!"
      raise e
    end

    it 'should check CraEntries::DestroyService existence' do
      puts "\n=== Testing CraEntries::DestroyService ==="

      begin
        puts "Checking if DestroyService exists..."

        # Try to access the service class
        service_class = CraEntries::DestroyService
        puts "✅ DestroyService class exists: #{service_class}"

        # Try to call it with minimal parameters
        puts "Calling DestroyService with minimal parameters..."
        result = service_class.call(entry: cra_entry, current_user: user)

        puts "✅ DestroyService call successful!"
        puts "Result: #{result.inspect}"

      rescue StandardError => e
        puts "❌ DestroyService call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    rescue LoadError, NameError => e
      puts "❌ DestroyService does not exist!"
      puts "Error: #{e.class} - #{e.message}"
      puts "This might be the source of the 500 errors - missing service!"
      raise e
    end

    it 'should test CraMissionLinker service' do
      puts "\n=== Testing CraMissionLinker ==="

      begin
        puts "Checking if CraMissionLinker exists..."

        # Try to access the service class
        linker_class = CraMissionLinker
        puts "✅ CraMissionLinker class exists: #{linker_class}"

        # Try to call it with minimal parameters
        puts "Calling CraMissionLinker.link_cra_to_mission!..."
        linker_class.link_cra_to_mission!(cra.id, mission.id)

        puts "✅ CraMissionLinker call successful!"

      rescue StandardError => e
        puts "❌ CraMissionLinker call failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    rescue LoadError, NameError => e
      puts "❌ CraMissionLinker does not exist!"
      puts "Error: #{e.class} - #{e.message}"
      puts "This might be the source of the 500 errors - missing service!"
      raise e
    end

    it 'should test model methods used by services' do
      puts "\n=== Testing Model Methods ==="

      begin
        puts "Testing Cra.accessible_to(user)..."
        accessible_cras = Cra.accessible_to(user)
        puts "✅ Cra.accessible_to(user) successful! Found: #{accessible_cras.count} CRAs"

        puts "Testing cra.locked?..."
        is_locked = cra.locked?
        puts "✅ cra.locked? = #{is_locked}"

        puts "Testing cra.submitted?..."
        is_submitted = cra.submitted?
        puts "✅ cra.submitted? = #{is_submitted}"

        puts "Testing CraEntry validations..."
        entry = CraEntry.new(
          date: Date.current,
          quantity: 1.0,
          unit_price: 60000,
          description: 'Test validation'
        )
        is_valid = entry.valid?
        puts "✅ CraEntry valid? = #{is_valid}"

        unless is_valid
          puts "CraEntry validation errors:"
          entry.errors.full_messages.each { |msg| puts "  - #{msg}" }
        end

      rescue StandardError => e
        puts "❌ Model method test failed!"
        puts "Error: #{e.class} - #{e.message}"
        puts "Backtrace:"
        e.backtrace.each { |line| puts "  #{line}" }
        raise e
      end
    end
  end
end
