#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# AUTOMATED STRUCTURE VALIDATION SCRIPT (PR15 - Phase 3)
# ==============================================================================
#
# Ce script valide automatiquement la structure des tests pour s'assurer qu'ils
# suivent les patterns établis dans PR15. Il détecte les violations de séparation
# entre contract tests et business logic tests.
#
# Usage:
#   ruby bin/templates/validate_structure.rb
#   ruby bin/templates/validate_structure.rb --output=report.md
#   ruby bin/templates/validate_structure.rb --fix
#
# Features:
#   - Validation de séparation contract/business logic
#   - Détection des violations de templates
#   - Analyse des patterns de code
#   - Génération de rapports détaillés
#   - Suggestions d'amélioration automatiques
#   - Mode de correction automatique (expérimental)

require 'fileutils'
require 'pathname'
require 'json'

# ==============================================================================
# STRUCTURE VALIDATOR CLASS
# ==============================================================================

class StructureValidator
  SPEC_DIR = Pathname.new('spec/requests')
  TEMPLATE_DIR = Pathname.new('spec/templates')
  SUPPORT_DIR = Pathname.new('spec/support')

  # Patterns de violation documentés
  VIOLATION_PATTERNS = {
    contract_test: [
      /calculat.*line_total/i,
      /validate.*business/i,
      /business.*rule/i,
      /quantity.*unit_price/i,
      /financial.*calculation/i
    ],
    business_logic_test: [
      /schema.*swagger/i,
      /match_json_schema/i,
      /response.*have_http_status/i,
      /parameter.*swagger/i,
      /type.*rswag/i
    ]
  }

  # Templates attendus
  EXPECTED_TEMPLATES = {
    contract: 'api_contract_spec_template.rb',
    business: 'business_logic_spec_template.rb'
  }

  attr_reader :violations, :warnings, :suggestions, :report_data

  def initialize
    @violations = []
    @warnings = []
    @suggestions = []
    @report_data = {
      timestamp: Time.now.iso8601,
      total_files: 0,
      contract_files: 0,
      business_files: 0,
      untagged_files: 0,
      template_usage: {},
      pattern_violations: [],
      suggestions: []
    }
  end

  def validate_all(output_path: nil, fix_mode: false)
    puts "🔍 Starting structure validation..."

    # Collecte des fichiers de test
    test_files = collect_test_files
    @report_data[:total_files] = test_files.size

    # Analyse de chaque fichier
    test_files.each do |file|
      analyze_file(file)
    end

    # Validation des templates
    validate_template_usage

    # Validation des patterns
    validate_patterns

    # Génération des suggestions
    generate_suggestions

    # Affichage du rapport
    display_report

    # Sauvegarde du rapport
    save_report(output_path) if output_path

    # Mode de correction automatique
    auto_fix if fix_mode

    # Code de sortie basé sur les violations
    @violations.empty? ? 0 : 1
  rescue => e
    puts "❌ Error during validation: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    1
  end

  private

  def collect_test_files
    Dir.glob(SPEC_DIR / '**/*_spec.rb').select do |file|
      # Exclure les templates et les fichiers de support
      !file.include?('templates') && !file.include?('support')
    end.sort
  end

  def analyze_file(file_path)
    content = File.read(file_path)
    relative_path = Pathname.new(file_path).relative_path_from(Pathname.new('.')).to_s

    puts "📋 Analyzing: #{relative_path}"

    # Détermination du type de test
    test_type = determine_test_type(content)

    case test_type
    when :contract
      @report_data[:contract_files] += 1
      validate_contract_test(relative_path, content)
    when :business
      @report_data[:business_files] += 1
      validate_business_test(relative_path, content)
    when :untagged
      @report_data[:untagged_files] += 1
      handle_untagged_file(relative_path, content)
    when :mixed
      @violations << {
        type: :mixed_concerns,
        file: relative_path,
        message: "File mixes contract and business logic tests",
        severity: :error
      }
    end

    # Analyse des patterns spécifiques
    analyze_patterns(relative_path, content, test_type)

    # Analyse de l'utilisation des helpers
    analyze_helper_usage(relative_path, content)
  end

  def determine_test_type(content)
    is_contract = content.include?('type: :rswag') || content.include?('swagger_doc')
    is_business = content.include?('type: :request') && !is_contract
    is_untagged = !is_contract && !is_business
    is_mixed = is_contract && has_business_logic_patterns?(content)

    case
    when is_mixed then :mixed
    when is_contract then :contract
    when is_business then :business
    when is_untagged then :untagged
    else :unknown
    end
  end

  def has_business_logic_patterns?(content)
    VIOLATION_PATTERNS[:contract_test].any? { |pattern| content.match?(pattern) }
  end

  def has_contract_patterns?(content)
    VIOLATION_PATTERNS[:business_logic_test].any? { |pattern| content.match?(pattern) }
  end

  def validate_contract_test(file_path, content)
    # Vérification des éléments requis pour les tests contract
    unless content.include?('include ApiContractHelpers')
      @violations << {
        type: :missing_helper,
        file: file_path,
        message: "Contract test missing 'include ApiContractHelpers'",
        severity: :warning
      }
    end

    unless content.include?('type: :rswag')
      @violations << {
        type: :missing_type,
        file: file_path,
        message: "Contract test missing 'type: :rswag'",
        severity: :error
      }
    end

    # Vérification des violations de business logic
    if has_business_logic_patterns?(content)
      @violations << {
        type: :business_logic_in_contract,
        file: file_path,
        message: "Contract test contains business logic patterns",
        severity: :error,
        patterns: VIOLATION_PATTERNS[:contract_test].select { |p| content.match?(p) }.map(&:source)
      }
    end
  end

  def validate_business_test(file_path, content)
    # Vérification des éléments requis pour les tests business logic
    unless content.include?('include BusinessLogicHelpers')
      @violations << {
        type: :missing_helper,
        file: file_path,
        message: "Business logic test missing 'include BusinessLogicHelpers'",
        severity: :warning
      }
    end

    unless content.include?('type: :request')
      @violations << {
        type: :missing_type,
        file: file_path,
        message: "Business logic test missing 'type: :request'",
        severity: :error
      }
    end

    # Vérification des violations de contract testing
    if has_contract_patterns?(content)
      @violations << {
        type: :contract_logic_in_business,
        file: file_path,
        message: "Business logic test contains contract testing patterns",
        severity: :error,
        patterns: VIOLATION_PATTERNS[:business_logic_test].select { |p| content.match?(p) }.map(&:source)
      }
    end
  end

  def handle_untagged_file(file_path, content)
    @warnings << {
      type: :untagged_file,
      file: file_path,
      message: "Test file is not tagged as contract or business logic",
      severity: :warning
    }

    # Suggestion de tag basé sur le contenu
    if content.include?('schema') || content.include?('swagger')
      @suggestions << {
        file: file_path,
        suggestion: "Consider adding 'type: :rswag' for API contract testing",
        action: :add_rswag_tag
      }
    elsif content.include?('calculate') || content.include?('validate')
      @suggestions << {
        file: file_path,
        suggestion: "Consider adding 'type: :request' for business logic testing",
        action: :add_request_tag
      }
    end
  end

  def analyze_patterns(file_path, content, test_type)
    # Analyse des patterns E2E documentés
    patterns = {
      date_format: /date\s*\+\s*%m/,
      json_parsing: /jq.*\.-r.*\.\w+/,
      uuid_handling: /to_i/,
      financial_calculation: /\d+\.\d+\s*\*\s*\d+/
    }

    patterns.each do |pattern_name, pattern|
      if content.match?(pattern)
        case test_type
        when :contract
          @violations << {
            type: :e2e_pattern_in_contract,
            file: file_path,
            message: "Contract test contains E2E pattern: #{pattern_name}",
            severity: :warning,
            pattern: pattern.source
          }
        when :business
          # Les patterns E2E sont acceptables dans les tests business logic
          @report_data[:pattern_violations] << {
            file: file_path,
            pattern: pattern_name,
            context: :business_logic,
            acceptable: true
          }
        end
      end
    end
  end

  def analyze_helper_usage(file_path, content)
    # Analyse de l'utilisation des helpers
    helpers_used = []

    if content.include?('include ApiContractHelpers')
      helpers_used << 'ApiContractHelpers'
    end

    if content.include?('include BusinessLogicHelpers')
      helpers_used << 'BusinessLogicHelpers'
    end

    if helpers_used.empty?
      @warnings << {
        type: :no_helpers,
        file: file_path,
        message: "Test file does not use any helpers",
        severity: :info
      }
    elsif helpers_used.size > 1
      @violations << {
        type: :multiple_helpers,
        file: file_path,
        message: "Test file uses multiple helpers: #{helpers_used.join(', ')}",
        severity: :error
      }
    end

    @report_data[:template_usage][file_path] = {
      helpers: helpers_used,
      has_contract_patterns: has_contract_patterns?(content),
      has_business_patterns: has_business_logic_patterns?(content)
    }
  end

  def validate_template_usage
    puts "📋 Validating template usage..."

    # Vérification de l'existence des templates
    EXPECTED_TEMPLATES.each do |type, filename|
      template_path = TEMPLATE_DIR / filename
      unless template_path.exist?
        @violations << {
          type: :missing_template,
          file: filename,
          message: "Required template not found: #{filename}",
          severity: :error
        }
      end
    end

    # Analyse de l'utilisation des patterns de templates
    template_files = Dir.glob(TEMPLATE_DIR / '*.rb')
    @report_data[:available_templates] = template_files.map { |f| Pathname.new(f).basename.to_s }
  end

  def validate_patterns
    puts "🔍 Validating code patterns..."

    # Validation des patterns documentés
    test_files = collect_test_files

    test_files.each do |file|
      content = File.read(file)
      relative_path = Pathname.new(file).relative_path_from(Pathname.new('.')).to_s

      # Pattern: Utilisation de Float pour les montants
      if content.match?(/\d+\.\d+.*\*.*\d+/) && !content.match?(/#.*cents?/i)
        @violations << {
          type: :float_calculation,
          file: relative_path,
          message: "Potential float calculation found - consider using cents",
          severity: :warning
        }
      end

      # Pattern: Parsing JSON incorrect
      if content.match?(/jq.*\.-r.*\.[^.]+$/) # Chemins JSON incomplets
        @violations << {
          type: :incomplete_json_path,
          file: relative_path,
          message: "Incomplete JSON path - consider using nested paths like 'data.entry.id'",
          severity: :warning
        }
      end
    end
  end

  def generate_suggestions
    puts "💡 Generating improvement suggestions..."

    # Suggestion basée sur les violations trouvées
    violation_types = @violations.map { |v| v[:type] }.uniq

    if violation_types.include?(:untagged_file)
      @suggestions << {
        category: :tagging,
        suggestion: "Add proper type tags (:rswag or :request) to all test files",
        priority: :high,
        files: @violations.select { |v| v[:type] == :untagged_file }.map { |v| v[:file] }
      }
    end

    if violation_types.include?(:missing_helper)
      @suggestions << {
        category: :helpers,
        suggestion: "Include appropriate helpers in test files",
        priority: :medium,
        files: @violations.select { |v| v[:type] == :missing_helper }.map { |v| v[:file] }
      }
    end

    if violation_types.include?(:mixed_concerns)
      @suggestions << {
        category: :separation,
        suggestion: "Separate contract and business logic into different test files",
        priority: :critical,
        files: @violations.select { |v| v[:type] == :mixed_concerns }.map { |v| v[:file] }
      }
    end

    @report_data[:suggestions] = @suggestions
  end

  def display_report
    puts "\n" + "="*60
    puts "📊 STRUCTURE VALIDATION REPORT"
    puts "="*60

    puts "\n📈 SUMMARY:"
    puts "  Total test files: #{@report_data[:total_files]}"
    puts "  Contract tests: #{@report_data[:contract_files]}"
    puts "  Business logic tests: #{@report_data[:business_files]}"
    puts "  Untagged files: #{@report_data[:untagged_files]}"
    puts "  Violations: #{@violations.size}"
    puts "  Warnings: #{@warnings.size}"
    puts "  Suggestions: #{@suggestions.size}"

    unless @violations.empty?
      puts "\n❌ VIOLATIONS (#{@violations.size}):"
      @violations.each do |violation|
        puts "  • [#{violation[:severity].upcase}] #{violation[:file]}"
        puts "    #{violation[:message]}"
        puts "    Type: #{violation[:type]}" if violation[:type]
      end
    end

    unless @warnings.empty?
      puts "\n⚠️  WARNINGS (#{@warnings.size}):"
      @warnings.each do |warning|
        puts "  • [#{warning[:severity].upcase}] #{warning[:file]}"
        puts "    #{warning[:message]}"
      end
    end

    unless @suggestions.empty?
      puts "\n💡 SUGGESTIONS (#{@suggestions.size}):"
      @suggestions.each do |suggestion|
        puts "  • [#{suggestion[:priority].upcase}] #{suggestion[:suggestion]}"
        if suggestion[:files]
          puts "    Files: #{suggestion[:files].first(3).join(', ')}"
          puts "    +#{suggestion[:files].size - 3} more" if suggestion[:files].size > 3
        end
      end
    end

    puts "\n📋 RECOMMENDATIONS:"
    if @violations.empty?
      puts "  ✅ All tests follow PR15 structure guidelines!"
    else
      puts "  🔧 Address violations to improve test structure"
      puts "  📖 Review templates in spec/templates/"
      puts "  📚 Check documentation in docs/technical/patterns/"
    end
  end

  def save_report(output_path)
    puts "\n💾 Saving report to: #{output_path}"

    report_content = generate_markdown_report

    File.write(output_path, report_content)
    puts "✅ Report saved successfully!"
  end

  def generate_markdown_report
    report = []

    report << "# Structure Validation Report"
    report << ""
    report << "**Generated:** #{@report_data[:timestamp]}"
    report << "**Total Files:** #{@report_data[:total_files]}"
    report << ""

    report << "## Summary"
    report << ""
    report << "| Metric | Count |"
    report << "|--------|-------|"
    report << "| Contract Tests | #{@report_data[:contract_files]} |"
    report << "| Business Logic Tests | #{@report_data[:business_files]} |"
    report << "| Untagged Files | #{@report_data[:untagged_files]} |"
    report << "| Violations | #{@violations.size} |"
    report << "| Warnings | #{@warnings.size} |"
    report << "| Suggestions | #{@suggestions.size} |"
    report << ""

    unless @violations.empty?
      report << "## Violations"
      report << ""
      @violations.each do |violation|
        report << "### #{violation[:file]}"
        report << ""
        report << "- **Type:** #{violation[:type]}"
        report << "- **Severity:** #{violation[:severity]}"
        report << "- **Message:** #{violation[:message]}"
        report << ""
      end
    end

    unless @suggestions.empty?
      report << "## Improvement Suggestions"
      report << ""
      @suggestions.each do |suggestion|
        report << "### #{suggestion[:category].capitalize}"
        report << ""
        report << "**Suggestion:** #{suggestion[:suggestion]}"
        report << "**Priority:** #{suggestion[:priority]}"
        report << ""
      end
    end

    report.join("\n")
  end

  def auto_fix
    puts "\n🔧 AUTO-FIX MODE (Experimental)"
    puts "="*40

    @suggestions.each do |suggestion|
      case suggestion[:action]
      when :add_rswag_tag
        suggestion[:files].each do |file|
          add_rswag_tag(file)
        end
      when :add_request_tag
        suggestion[:files].each do |file|
          add_request_tag(file)
        end
      end
    end

    puts "✅ Auto-fix completed!"
  end

  def add_rswag_tag(file_path)
    content = File.read(file_path)

    # Ajouter le tag rswag après la ligne describe
    if content.include?('describe ') && !content.include?('type: :rswag')
      modified_content = content.gsub(/(describe\s+.*\n)/, "\\1  include ApiContractHelpers\n")
      File.write(file_path, modified_content)
      puts "  ✅ Added RSwag tag to: #{file_path}"
    end
  rescue => e
    puts "  ❌ Failed to fix #{file_path}: #{e.message}"
  end

  def add_request_tag(file_path)
    content = File.read(file_path)

    # Ajouter le tag request après la ligne describe
    if content.include?('describe ') && !content.include?('type: :request')
      modified_content = content.gsub(/(describe\s+.*\n)/, "\\1  include BusinessLogicHelpers\n")
      File.write(file_path, modified_content)
      puts "  ✅ Added request tag to: #{file_path}"
    end
  rescue => e
    puts "  ❌ Failed to fix #{file_path}: #{e.message}"
  end
end

# ==============================================================================
# COMMAND LINE INTERFACE
# ==============================================================================

if __FILE__ == $PROGRAM_NAME
  require 'optparse'

  options = {}
  output_file = nil
  fix_mode = false

  OptionParser.new do |parser|
    parser.banner = "Usage: #{$PROGRAM_NAME} [options]"

    parser.on('--output=PATH', 'Save report to file (markdown format)') do |path|
      output_file = path
    end

    parser.on('--fix', 'Enable experimental auto-fix mode') do
      fix_mode = true
    end

    parser.on('--json', 'Output results in JSON format') do
      options[:json] = true
    end

    parser.on('--help', 'Show this help message') do
      puts parser
      puts
      puts "Examples:"
      puts "  #{$PROGRAM_NAME}"
      puts "  #{$PROGRAM_NAME} --output=structure-report.md"
      puts "  #{$PROGRAM_NAME} --fix"
      puts "  #{$PROGRAM_NAME} --json"
      exit
    end
  end.parse!

  # Vérification de l'environnement
  unless File.exist?('config/application.rb')
    puts "❌ Error: Must be run from Rails project root"
    puts "   Current directory: #{Dir.pwd}"
    exit 1
  end

  unless File.directory?(SPEC_DIR.to_s)
    puts "❌ Error: Spec directory not found: #{SPEC_DIR}"
    exit 1
  end

  # Exécution de la validation
  validator = StructureValidator.new
  exit_code = validator.validate_all(output_path: output_file, fix_mode: fix_mode)

  # Sortie en JSON si demandé
  if options[:json]
    puts "\n" + JSON.pretty_generate({
      violations: validator.violations,
      warnings: validator.warnings,
      suggestions: validator.suggestions,
      report_data: validator.report_data
    })
  end

  exit(exit_code)
end
