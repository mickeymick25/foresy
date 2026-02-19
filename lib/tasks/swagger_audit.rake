# frozen_string_literal:

# Rake task to audit exhaustiveness of Routes vs Swagger documentation
#
# Usage: rake swagger:audit_coverage
#
# This task:
# 1. Extracts all public API v1 routes from Rails
# 2. Parses swagger/v1/swagger.yaml
# 3. Compares documented vs actual routes
# 4. Reports missing endpoints in both directions
# 5. Exits with error code if mismatch found
#
# Exit codes:
# 0 = All routes documented (or exclusions approved)
# 1 = Mismatch found (missing in Swagger or extra routes)

namespace :swagger do
  desc 'Audit exhaustiveness of Routes vs Swagger documentation'
  task audit_coverage: :environment do
    puts "\n🔍 Phase 1.7: Routes ↔ Swagger Exhaustiveness Audit\n"
    puts "=" * 60

    # 1. Extract all API v1 routes
    routes = extract_api_v1_routes

    # 2. Parse Swagger.yaml
    swagger_endpoints = parse_swagger_yaml

    # 3. Normalize paths for comparison
    normalized_routes = normalize_routes(routes)
    normalized_swagger = normalize_swagger_paths(swagger_endpoints)

    # 4. Compare
    missing_in_swagger = normalized_routes - normalized_swagger
    missing_in_routes = normalized_swagger - normalized_routes

    # 5. Report results
    report_results(normalized_routes, normalized_swagger, missing_in_swagger, missing_in_routes)

    # 6. Exit with appropriate code
    if missing_in_swagger.empty? && missing_in_routes.empty?
      puts "\n✅ AUDIT PASSED - All routes are documented"
      exit 0
    else
      puts "\n❌ AUDIT FAILED - Mismatch detected"
      exit 1
    end
  end
end

# ============================================================================
# Exclusion list for routes that should NOT be in Swagger
# These are non-contractual routes that should be excluded from the audit
# Paths to exclude from BOTH Rails routes AND Swagger documentation
# These are non-contractual routes that should not be part of the API contract
EXCLUDED_PATHS = [
  '/health',                      # Health check endpoints
  '/api/health',                  # API health check
  '/up',                          # Rails health check
  '/rails/health',                # Rails internal health
  '/rails/info',                  # Rails info
  '/rails/routes',                # Rails internal
  '/rails/info/properties',       # Rails internal
  '/rails/mailers',              # Rails internal
  '/rails/assets',               # Rails internal assets
].freeze

EXCLUDED_PREFIXES = [
  '/rails/',                      # All Rails internal routes
  '/active_storage/',             # ActiveStorage routes if present
  '/webpacker/',                  # Webpacker routes if present
].freeze

# ============================================================================
# Helper Methods
# ============================================================================

def extract_api_v1_routes
  routes = []

  Rails.application.routes.routes.each do |route|
    # Get the path
    path = route.path.spec.to_s

    # Skip if not API v1
    next unless path.start_with?('/api/v1')

    # Get the verb
    verb = route.verb.to_s.gsub(/[^A-Z]/, '').downcase

    # Skip if no verb (redirect routes, etc.)
    next if verb.empty?

    # Extract controller and action
    controller = route.defaults[:controller]
    action = route.defaults[:action]

    # Skip internal Rails routes
    next if controller.nil?
    next if controller.start_with?('rails/')
    next if controller.start_with?('rswag/')

    # Apply exclusion list to Rails routes
    path_without_format = path.gsub(/\(\.:format\)/, '')
    next if EXCLUDED_PATHS.include?(path_without_format)
    next if EXCLUDED_PREFIXES.any? { |prefix| path_without_format.start_with?(prefix) }

    routes << {
      path: path,
      verb: verb,
      controller: controller,
      action: action
    }
  end

  routes
end

def parse_swagger_yaml
  swagger_path = File.join(Rails.root, 'swagger', 'v1', 'swagger.yaml')

  unless File.exist?(swagger_path)
    puts "❌ ERROR: swagger/v1/swagger.yaml not found"
    exit 1
  end

  require 'yaml'
  swagger = YAML.safe_load(File.read(swagger_path))

  endpoints = []

  return endpoints unless swagger['paths']

  swagger['paths'].each do |path, methods|
    next unless methods.is_a?(Hash)

    methods.each do |verb, details|
      # Skip $ref and other non-http operations
      next unless verb.is_a?(String)
      next unless %w[get post put patch delete].include?(verb.downcase)

      endpoints << {
        path: path,
        verb: verb.downcase,
        summary: details['summary'] || 'No summary'
      }
    end
  end

  endpoints
end

def normalize_routes(routes)
  normalized = []

  routes.each do |route|
    path = route[:path]
    verb = route[:verb]

    # Remove .(.:format) suffix
    path = path.gsub(/\(\.:format\)/, '')

    # Convert :id to {id}
    path = path.gsub(/:(\w+)/, '{\1}')

    # Remove trailing slashes
    path = path.gsub(/\/+$/, '')

    normalized << "#{verb} #{path}"
  end

  normalized.sort
end

def normalize_swagger_paths(endpoints)
  normalized = []

  endpoints.each do |endpoint|
    path = endpoint[:path]
    verb = endpoint[:verb]

    # Apply exclusion list to Swagger paths
    next if EXCLUDED_PATHS.include?(path)
    next if EXCLUDED_PREFIXES.any? { |prefix| path.start_with?(prefix) }

    # Remove trailing slashes
    path = path.gsub(/\/+$/, '')

    normalized << "#{verb} #{path}"
  end

  normalized.sort
end

def report_results(routes, swagger, missing_in_swagger, missing_in_routes)
  puts "\n📊 RESULTS:\n\n"

  puts "Total Rails API v1 routes: #{routes.count}"
  puts "Total Swagger documented: #{swagger.count}"

  puts "\n" + "-" * 60

  unless missing_in_swagger.empty?
    puts "\n❌ MISSING IN SWAGGER (#{missing_in_swagger.count}):\n"
    missing_in_swagger.each do |route|
      verb, path = route.split(' ', 2)
      puts "  - #{verb.upcase} #{path}"
    end
  end

  unless missing_in_routes.empty?
    puts "\n⚠️  MISSING IN ROUTES - Extra in Swagger (#{missing_in_routes.count}):\n"
    missing_in_routes.each do |route|
      verb, path = route.split(' ', 2)
      puts "  - #{verb.upcase} #{path}"
    end
  end

  if missing_in_swagger.empty? && missing_in_routes.empty?
    puts "\n✅ Perfect match - All routes documented!"
  end
end
