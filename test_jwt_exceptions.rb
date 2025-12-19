# test_jwt_exceptions.rb
# Script simplifié pour vérifier JWT::InvalidIatError dans la gem jwt v2.10.1

require 'bundler/setup'
require 'jwt'

puts "🔍 TEST JWT EXCEPTIONS - Version #{JWT::VERSION}"
puts '=' * 50

# Test principal: JWT::InvalidIatError existe-t-il ?
puts "\n🎯 QUESTION PRINCIPALE: JWT::InvalidIatError existe-t-il ?"
puts '-' * 45

begin
  # Tenter de référencer JWT::InvalidIatError
  exception_class = JWT::InvalidIatError
  puts "✅ OUI! JWT::InvalidIatError existe: #{exception_class}"
  puts "   Classe: #{exception_class.superclass}"
rescue NameError => e
  puts "❌ NON! JWT::InvalidIatError n'existe pas"
  puts "   Erreur: #{e.message}"
end

# Liste de toutes les exceptions JWT disponibles
puts "\n📋 TOUTES LES EXCEPTIONS JWT DISPONIBLES:"
puts '-' * 40

jwt_exceptions = []
JWT.constants.each do |const_name|
  const = JWT.const_get(const_name)
  jwt_exceptions << const_name if const.is_a?(Class) && const < StandardError
end

jwt_exceptions.each do |exception_name|
  puts "  ✅ JWT::#{exception_name}"
end

# Test pratique avec des tokens invalides
puts "\n🔬 TESTS PRATIQUES AVEC TOKENS INVALIDES:"
puts '-' * 45

secret_key = 'test_secret_key'

test_cases = [
  { name: 'Token malformé', token: 'invalid.token' },
  { name: 'Token signature invalide', token: JWT.encode({ user_id: 123 }, 'wrong_key') },
  { name: 'Token expiré', token: JWT.encode({ user_id: 123, exp: Time.now.to_i - 3600 }, secret_key) }
]

test_cases.each do |test|
  puts "\n🧪 #{test[:name]}:"
  begin
    result = JWT.decode(test[:token], secret_key)[0]
    puts "   ✅ Succès: #{result.inspect}"
  rescue StandardError => e
    puts "   ⚠️  Exception: #{e.class.name}"
    puts "      Message: #{e.message}"
  end
end

# Conclusion
puts "\n📊 CONCLUSION:"
puts '=' * 20

if JWT.const_defined?(:InvalidIatError)
  puts "✅ JWT::InvalidIatError existe dans jwt #{JWT::VERSION}"
  puts "✅ La gestion d'exceptions dans AuthenticationService est CORRECTE"
  puts '✅ Aucune correction nécessaire pour ce point'
else
  puts "❌ JWT::InvalidIatError n'existe pas dans jwt #{JWT::VERSION}"
  puts '⚠️  Il faudrait modifier AuthenticationService pour utiliser un fallback'
end

puts "\n🏁 Test terminé!"
