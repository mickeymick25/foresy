# frozen_string_literal: true

# Debug script for CraServices::Export
# Usage: rails runner debug_export.rb

require_relative 'config/environment'

puts '=== Debugging CraServices::Export ==='

# Create test data
user = User.first
if user.nil?
  user = User.create!(email: 'debug_test@example.com', name: 'Debug Test')
  puts "Created user: #{user.id}"
end

puts "\n1. Creating CRA..."
cra = Cra.create!(created_by_user_id: user.id, status: 'submitted', year: 2026, month: 1)
puts "   CRA created: id=#{cra.id}, status=#{cra.status}"

puts "\n2. Creating CraEntry..."
entry = CraEntry.create!(quantity: 1, unit_price: 50_000, date: Date.current, description: 'Test work')
puts "   Entry created: id=#{entry.id}"

puts "\n3. Creating join table entry..."
join = CraEntryCra.create!(cra: cra, cra_entry: entry)
puts "   Join created: id=#{join.id}"

puts "\n4. Checking associations..."
puts "   cra.cra_entries.count: #{cra.cra_entries.count}"
puts "   cra.cra_entries.inspect: #{cra.cra_entries.inspect}"

if cra.cra_entries.any?
  first_entry = cra.cra_entries.first
  puts "   First entry: id=#{first_entry.id}"
  puts "   First entry missions: #{first_entry.missions.inspect}"
end

puts "\n5. Calling CraServices::Export..."
begin
  result = CraServices::Export.call(cra: cra, current_user: user)
  puts "   Result success?: #{result.success?}"
  puts "   Result status: #{result.status}"
  puts "   Result error: #{result.error}"
  puts "   Result message: #{result.message}"
  if result.data
    puts "   Result data type: #{result.data.class.name}"
    puts "   Result data length: #{result.data.length}"
    puts "   Result data preview: #{result.data[0..100]}..."
  else
    puts '   Result data: nil'
  end
rescue StandardError => e
  puts "   EXCEPTION: #{e.class}: #{e.message}"
  puts '   Backtrace:'
  e.backtrace.first(10).each { |line| puts "      #{line}" }
end

puts "\n6. Cleaning up..."
CraEntryCra.where(cra: cra, cra_entry: entry).destroy_all
CraEntry.destroy(entry.id)
Cra.destroy(cra.id)
puts '   Cleanup done'

puts "\n=== Debug complete ==="
