# frozen_string_literal: true

# Rake task to validate strict schema compliance in Swagger documentation
#
# Usage: rake swagger:validate_schemas
#
# This task:
# 1. Parses swagger/v1/swagger.yaml
# 2. Validates that all schemas have required fields defined
# 3. Validates that all schemas have additionalProperties: false
# 4. Reports any schemas that don't meet Platinum governance criteria
# 5. Exits with error code if validation fails
#
# Exit codes:
# 0 = All schemas are compliant
# 1 = Validation failed (non-compliant schemas found)

namespace :swagger do
  desc 'Validate strict schema compliance (required + additionalProperties: false)'
  task validate_schemas: :environment do
    puts "\n🔍 Phase 1.6: Schema Strict Validation\n"
    puts '=' * 60

    # Load and parse swagger.yaml
    swagger = load_swagger_yaml

    # Get all schemas from components
    schemas = swagger.dig('components', 'schemas') || {}

    puts "\n📋 Found #{schemas.count} schemas to validate\n"

    # Track validation results
    errors = []
    warnings = []

    schemas.each do |name, schema|
      next unless schema.is_a?(Hash)

      # Check for required fields (skip for UpdateRequest schemas - they're for PATCH which allows partial updates)
      unless schema['required'].present? || name.end_with?('UpdateRequest')
        errors << "Schema '#{name}' has no required fields declared"
      end

      # Check for additionalProperties: false
      if schema['properties'].present? && schema['additionalProperties'] != false
        errors << "Schema '#{name}' should have additionalProperties: false"
      end

      # Check nested schemas in properties
      if schema['properties'].is_a?(Hash)
        schema['properties'].each do |prop_name, prop_schema|
          next unless prop_schema.is_a?(Hash)

          # Check object properties
          if prop_schema['properties'].present? && prop_schema['additionalProperties'] != false
            errors << "Schema '#{name}' property '#{prop_name}' should have additionalProperties: false"
          end
        end
      end
    end

    # Report results
    if errors.empty?
      puts "\n✅ VALIDATION PASSED - All schemas are compliant"
      puts "   - All schemas have required fields"
      puts "   - All schemas have additionalProperties: false"
      puts "\n📊 Summary: #{schemas.count} schemas validated"
      exit 0
    else
      puts "\n❌ VALIDATION FAILED - Schema compliance issues found\n"
      errors.each do |error|
        puts "   ❌ #{error}"
      end
      puts "\n📊 Summary: #{errors.count} issues found in #{schemas.count} schemas"
      exit 1
    end
  end
end

# ============================================================================
# Helper Methods
# ============================================================================

def load_swagger_yaml
  swagger_path = File.join(Rails.root, 'swagger', 'v1', 'swagger.yaml')

  unless File.exist?(swagger_path)
    puts '❌ ERROR: swagger/v1/swagger.yaml not found'
    exit 1
  end

  require 'yaml'
  swagger = YAML.safe_load_file(swagger_path)

  unless swagger.is_a?(Hash)
    puts '❌ ERROR: Invalid swagger.yaml format'
    exit 1
  end

  swagger
end
