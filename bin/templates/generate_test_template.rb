#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# AUTOMATED TEST TEMPLATE GENERATOR (PR15 - Phase 3)
# ==============================================================================
#
# Ce script génère automatiquement de nouveaux tests en utilisant les templates
# créés selon le plan PR15. Il valide la structure et s'assure que les
# nouveaux tests suivent les patterns établis.
#
# Usage:
#   ./bin/templates/generate_test_template.rb [options]
#
# Options:
#   --type=contract|logic|both     Type de test à générer
#   --name=NOM                     Nom du feature (ex: fc08_entreprise)
#   --interactive                   Mode interactif
#   --force                        Écraser les fichiers existants
#   --dry-run                      Afficher ce qui serait fait sans créer
#
# Exemples:
#   ./bin/templates/generate_test_template.rb --type=contract --name=fc08_entreprise
#   ./bin/templates/generate_test_template.rb --interactive
#
# Ce script suit les patterns documentés dans PR15:
# - Separation contract/business logic
# - Template usage standards
# - Naming conventions
# - Structure validation

require 'fileutils'
require 'erb'
require 'pathname'

class TemplateGenerator
  class Error < StandardError; end

  TEMPLATE_DIR = Pathname.new('spec/templates')
  SPEC_DIR = Pathname.new('spec/requests')
  SUPPORT_DIR = Pathname.new('spec/support')

  attr_reader :options, :template_type, :feature_name, :output_file

  def initialize(options = {})
    @options = options
    @template_type = options[:type]
    @feature_name = options[:name]
    @dry_run = options[:dry_run] || false
    @force = options[:force] || false
    @interactive = options[:interactive] || false

    validate_environment!
  end

  def run
    puts "🚀 Template Generator (PR15 - Phase 3)"
    puts "=" * 50

    if @interactive
      interactive_mode
    else
      validate_required_options!
      generate_templates
    end

    puts "✅ Template generation completed successfully!"
    puts "📋 Next steps:"
    puts "   1. Review generated files"
    puts "   2. Customize templates for your feature"
    puts "   3. Add actual test cases"
    puts "   4. Run tests to validate"
  rescue Error => e
    puts "❌ Error: #{e.message}"
    exit 1
  rescue => e
    puts "❌ Unexpected error: #{e.message}"
    puts e.backtrace if @dry_run || @force
    exit 1
  end

  private

  def interactive_mode
    puts "🎯 Interactive Template Generation"
    puts

    # Sélection du type de test
    puts "Select test type:"
    puts "1. API Contract Test (RSwag)"
    puts "2. Business Logic Test"
    puts "3. Both (Recommended)"
    print "Choice (1-3): "

    choice = gets.chomp
    @template_type = case choice
    when '1' then 'contract'
    when '2' then 'logic'
    when '3' then 'both'
    else raise Error, "Invalid choice: #{choice}"
    end

    # Nom du feature
    puts
    print "Feature name (e.g., fc08_entreprise): "
    @feature_name = gets.chomp.strip

    validate_required_options!

    # Confirmation
    puts
    puts "Template generation summary:"
    puts "  Type: #{@template_type}"
    puts "  Name: #{@feature_name}"
    puts "  Output: spec/requests/"
    puts

    print "Continue? (y/N): "
    confirm = gets.chomp.downcase
    raise Error, "Generation cancelled" unless confirm == 'y'
  end

  def generate_templates
    case @template_type
    when 'contract'
      generate_api_contract_template
    when 'logic'
      generate_business_logic_template
    when 'both'
      generate_api_contract_template
      generate_business_logic_template
    else
      raise Error, "Invalid template type: #{@template_type}"
    end
  end

  def generate_api_contract_template
    source = TEMPLATE_DIR.join('api_contract_spec_template.rb')
    target = SPEC_DIR.join("#{@feature_name}_contract_spec.rb")

    raise Error, "Source template not found: #{source}" unless source.exist?

    validate_output_file!(target)

    content = render_template(source, generate_template_variables(:contract))

    if @dry_run
      puts "📄 Would create: #{target}"
      puts "Content preview:"
      puts content[0..200] + "..." if content.length > 200
    else
      write_file(target, content)
      puts "✅ Created: #{target}"
    end

    validate_generated_file!(target, :contract)
  end

  def generate_business_logic_template
    source = TEMPLATE_DIR.join('business_logic_spec_template.rb')
    target = SPEC_DIR.join("#{@feature_name}_logic_spec.rb")

    raise Error, "Source template not found: #{source}" unless source.exist?

    validate_output_file!(target)

    content = render_template(source, generate_template_variables(:logic))

    if @dry_run
      puts "📄 Would create: #{target}"
      puts "Content preview:"
      puts content[0..200] + "..." if content.length > 200
    else
      write_file(target, content)
      puts "✅ Created: #{target}"
    end

    validate_generated_file!(target, :logic)
  end

  def generate_template_variables(type)
    {
      feature_name: @feature_name,
      feature_class_name: feature_class_name,
      feature_module_name: feature_module_name,
      template_type: type.to_s,
      timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      current_year: Time.now.year,
      feature_description: feature_description
    }
  end

  def feature_class_name
    @feature_name.split('_').map(&:capitalize).join
  end

  def feature_module_name
    @feature_name.split('_').map(&:capitalize).join('::')
  end

  def feature_description
    case @feature_name
    when /^fc\d+/
      "Feature Contract #{@feature_name.split('_')[0].upcase}"
    else
      @feature_name.split('_').map(&:capitalize).join(' ')
    end
  end

  def render_template(source, variables)
    template = File.read(source)
    ERB.new(template, trim_mode: '-').result(binding)
  end

  def validate_output_file!(target)
    if target.exist? && !@force
      raise Error, "Output file already exists: #{target}. Use --force to overwrite."
    end

    # Vérifier que le dossier parent existe
    target.dirname.mkpath unless @dry_run
  end

  def validate_generated_file!(file, expected_type)
    content = File.read(file) unless @dry_run

    case expected_type
    when :contract
      unless content.include?('type: :rswag')
        raise Error, "Generated contract test missing required type: :rswag"
      end
      unless content.include?('include ApiContractHelpers')
        raise Error, "Generated contract test missing required helper: ApiContractHelpers"
      end
    when :logic
      unless content.include?('type: :request')
        raise Error, "Generated logic test missing required type: :request"
      end
      unless content.include?('include BusinessLogicHelpers')
        raise Error, "Generated logic test missing required helper: BusinessLogicHelpers"
      end
    end
  end

  def write_file(target, content)
    File.write(target, content)
    File.chmod(0644, target)
  end

  def validate_environment!
    raise Error, "Not in Rails project root" unless File.exist?('config/application.rb')
    raise Error, "Templates directory not found: #{TEMPLATE_DIR}" unless TEMPLATE_DIR.exist?
    raise Error, "Spec directory not found: #{SPEC_DIR}" unless SPEC_DIR.exist?
  end

  def validate_required_options!
    raise Error, "Template type required (--type=contract|logic|both)" if @template_type.nil?
    raise Error, "Feature name required (--name=FEATURE_NAME)" if @feature_name.nil?
    raise Error, "Invalid template type: #{@template_type}" unless %w[contract logic both].include?(@template_type)

    # Valider le nom du feature
    unless @feature_name =~ /^[a-z][a-z0-9_]*$/
      raise Error, "Feature name must be lowercase with underscores (e.g., fc08_entreprise)"
    end
  end
end

# ==============================================================================
# COMMAND LINE INTERFACE
# ==============================================================================

if __FILE__ == $PROGRAM_NAME
  require 'optparse'

  options = {}

  OptionParser.new do |parser|
    parser.banner = "Usage: #{$PROGRAM_NAME} [options]"

    parser.on('--type=TYPE', 'Type of test template (contract|logic|both)') do |type|
      options[:type] = type
    end

    parser.on('--name=NAME', 'Feature name (e.g., fc08_entreprise)') do |name|
      options[:name] = name
    end

    parser.on('--interactive', 'Run in interactive mode') do
      options[:interactive] = true
    end

    parser.on('--force', 'Overwrite existing files') do
      options[:force] = true
    end

    parser.on('--dry-run', 'Show what would be done without creating files') do
      options[:dry_run] = true
    end

    parser.on('--help', 'Show this help message') do
      puts parser
      puts
      puts "Examples:"
      puts "  #{$PROGRAM_NAME} --type=contract --name=fc08_entreprise"
      puts "  #{$PROGRAM_NAME} --type=both --name=fc09_notifications"
      puts "  #{$PROGRAM_NAME} --interactive"
      exit
    end
  end.parse!

  generator = TemplateGenerator.new(options)
  generator.run
end

# ==============================================================================
# TEMPLATE VALIDATION HELPERS
# ==============================================================================
# Ces helpers peuvent être utilisés pour valider la structure des tests générés

module TemplateValidationHelpers
  def self.validate_test_structure(file_path, expected_type)
    content = File.read(file_path)
    errors = []

    case expected_type
    when :contract
      errors << "Missing 'type: :rswag'" unless content.include?('type: :rswag')
      errors << "Missing 'include ApiContractHelpers'" unless content.include?('include ApiContractHelpers')
      errors << "Should not include business logic" if content.include?('calculate_line_total')
    when :logic
      errors << "Missing 'type: :request'" unless content.include?('type: :request')
      errors << "Missing 'include BusinessLogicHelpers'" unless content.include?('include BusinessLogicHelpers')
      errors << "Should not include API contract tests" if content.include?('schema') && content.include?('swagger')
    end

    errors
  end

  def self.suggest_improvements(file_path)
    content = File.read(file_path)
    suggestions = []

    # Vérifier les patterns documentés
    suggestions << "Consider using date format helpers" if content.include?('Date.current')
    suggestions << "Consider using financial calculation helpers" if content.match?(/\d+\.\d+\s*\*\s*\d+/)
    suggestions << "Consider using UUID validation helpers" if content.include?('SecureRandom.uuid')

    suggestions
  end
end
