# Domain Leakage Detector - Step 3.3 Implementation
# Automatically detects violations of Domain → ApplicationResult mapping rules
# Authority: CTO/Co-CTO Validated
# Date: 2026-01-21

require 'set'
require 'json'

class DomainLeakageDetector
  # Patterns that indicate domain leakage violations
  VIOLATION_PATTERNS = {
    domain_object_exposure: {
      pattern: /ApplicationResult\.success\([^)]*data:\s*[^,}]*\b(Domain|Cra|Mission)::[A-Z][a-zA-Z_]*\b/,
      description: "Raw Domain object exposed in ApplicationResult.data",
      severity: :critical
    },

    domain_exception_propagation: {
      pattern: /rescue\s+(Domain|Cra|Mission)::[A-Z][a-zA-Z_]*Error/,
      description: "Domain exception rescue outside Application Service layer",
      severity: :critical
    },

    non_standardized_error_type: {
      pattern: /ApplicationResult\.(\w+_error)/,
      description: "Non-standard ApplicationResult error type",
      severity: :high,
      validator: ->(error_type) { STANDARD_ERROR_TYPES.include?(error_type.to_sym) }
    },

    business_logic_in_controller: {
      pattern: /class\s+(\w*Controller).*def\s+(create|update|show|index).*(if|unless|while|case).*(business|rule|validate|check|lock|submit)/,
      description: "Business logic found in controller",
      severity: :critical
    },

    direct_domain_access: {
      pattern: /\b(Cra|Mission|Domain)::[A-Z][a-zA-Z_]*\.new\b|\b(Cra|Mission|Domain)::[A-Z][a-zA-Z_]*\.find\b|\b(Cra|Mission|Domain)::[A-Z][a-zA-Z_]*\.where\b/,
      description: "Direct domain access without Application Service",
      severity: :medium
    },

    active_record_exposure: {
      pattern: /ApplicationResult\.success\([^)]*data:\s*[^,}]*\b[A-Z][a-zA-Z_]*\.where\b|\b[A-Z][a-zA-Z_]*\.find_by\b/,
      description: "ActiveRecord objects exposed in ApplicationResult",
      severity: :medium
    },

    service_without_application_result: {
      pattern: /def\s+call[^)]*\n(?!.*return\s+ApplicationResult)/m,
      description: "Service call method does not return ApplicationResult",
      severity: :critical
    },

    mixed_contract_patterns: {
      pattern: /return\s*\{[^}]*(success|error|data)[^}]*\}/,
      description: "Mixed return contract patterns (hash returns)",
      severity: :critical
    }
  }.freeze

  # Standard error types allowed in ApplicationResult
  STANDARD_ERROR_TYPES = %i[
    validation_error unauthorized conflict not_found internal_error
  ].freeze

  class Violation
    attr_reader :type, :file, :line, :message, :severity, :suggested_fix

    def initialize(type, file, line, message, severity, suggested_fix = nil)
      @type = type
      @file = file
      @line = line
      @message = message
      @severity = severity
      @suggested_fix = suggested_fix
    end

    def to_h
      {
        type: @type,
        file: @file,
        line: @line,
        message: @message,
        severity: @severity,
        suggested_fix: @suggested_fix
      }
    end

    def critical?
      @severity == :critical
    end

    def high?
      @severity == :high
    end

    def medium?
      @severity == :medium
    end
  end

  class ScanResult
    attr_reader :violations, :files_scanned, :scan_time

    def initialize
      @violations = []
      @files_scanned = 0
      @scan_time = 0
    end

    def add_violation(violation)
      @violations << violation
    end

    def critical_violations
      @violations.select(&:critical?)
    end

    def high_violations
      @violations.select(&:high?)
    end

    def medium_violations
      @violations.select(&:medium?)
    end

    def total_violations
      @violations.size
    end

    def clean_scan?
      @violations.empty?
    end

    def violations_by_file
      @violations.group_by(&:file)
    end

    def violations_by_type
      @violations.group_by(&:type)
    end

    def to_h
      {
        violations: @violations.map(&:to_h),
        files_scanned: @files_scanned,
        scan_time: @scan_time,
        summary: {
          total: total_violations,
          critical: critical_violations.size,
          high: high_violations.size,
          medium: medium_violations.size,
          clean_scan: clean_scan?
        }
      }
    end

    def to_json
      JSON.pretty_generate(to_h)
    end
  end

  # Main detection method
  def self.detect(code_content, file_path = "unknown")
    violations = []

    VIOLATION_PATTERNS.each do |violation_type, config|
      pattern = config[:pattern]
      matches = code_content.enum_for(:scan, pattern).map { Regexp.last_match }

      matches.each do |match|
        message = build_violation_message(violation_type, config, match)
        suggested_fix = build_suggested_fix(violation_type, match)

        violations << Violation.new(
          violation_type,
          file_path,
          match.begin(0),
          message,
          config[:severity],
          suggested_fix
        )
      end
    end

    violations
  end

  # Scan a specific file
  def self.scan_file(file_path)
    return [] unless File.exist?(file_path)

    content = File.read(file_path)
    detect(content, file_path)
  end

  # Scan multiple files
  def self.scan_files(file_paths)
    result = ScanResult.new
    start_time = Time.current

    file_paths.each do |file_path|
      next unless File.exist?(file_path)

      violations = scan_file(file_path)
      violations.each { |v| result.add_violation(v) }
      result.files_scanned += 1
    end

    result.scan_time = (Time.current - start_time).round(2)
    result
  end

  # Scan application for violations
  def self.scan_application(paths = nil)
    paths ||= default_scan_paths

    result = ScanResult.new
    start_time = Time.current

    paths.each do |path|
      if File.directory?(path)
        files = Dir.glob("#{path}/**/*.rb")
        files.each do |file|
          violations = scan_file(file)
          violations.each { |v| result.add_violation(v) }
          result.files_scanned += 1
        end
      elsif File.exist?(path)
        violations = scan_file(path)
        violations.each { |v| result.add_violation(v) }
        result.files_scanned += 1
      end
    end

    result.scan_time = (Time.current - start_time).round(2)
    result
  end

  # Scan only Application Services
  def self.scan_application_services
    service_paths = [
      'app/services/**/*.rb',
      'lib/services/**/*.rb'
    ]

    files = service_paths.flat_map { |pattern| Dir.glob(pattern) }
    scan_files(files)
  end

  # Scan only Controllers
  def self.scan_controllers
    controller_paths = [
      'app/controllers/**/*.rb'
    ]

    files = controller_paths.flat_map { |pattern| Dir.glob(pattern) }
    scan_files(files)
  end

  # Runtime validation for Application Services
  def self.validate_service_contract(service_class)
    violations = []

    # Check if service inherits from ApplicationService or includes it
    unless service_class.ancestors.include?(ApplicationService)
      violations << Violation.new(
        :missing_application_service_inheritance,
        service_class.name || 'Unknown',
        0,
        "Service does not inherit from ApplicationService",
        :critical
      )
    end

    # Check if call method exists and returns ApplicationResult
    if service_class.instance_methods.include?(:call)
      # This would require runtime testing
      # For now, we'll check the source code
      source = service_class.instance_method(:call).source_location
      if source
        file_content = File.read(source[0])
        if file_content !~ /return.*ApplicationResult|ApplicationResult\./
          violations << Violation.new(
            :missing_application_result_return,
            source[0],
            source[1],
            "Service call method does not return ApplicationResult",
            :critical
          )
        end
      end
    end

    violations
  end

  # Generate detailed report
  def self.generate_report(result, output_path = nil)
    output_path ||= "outputs/reports/day3/domain_leakage_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"

    # Ensure output directory exists
    FileUtils.mkdir_p(File.dirname(output_path))

    File.write(output_path, result.to_json)

    # Also generate human-readable report
    text_output_path = output_path.sub('.json', '.txt')
    File.write(text_output_path, generate_text_report(result))

    {
      json_report: output_path,
      text_report: text_output_path,
      result: result
    }
  end

  # Generate text report
  def self.generate_text_report(result)
    report = []
    report << "=" * 80
    report << "DOMAIN LEAKAGE DETECTION REPORT"
    report << "=" * 80
    report << ""
    report << "Scan Summary:"
    report << "  Files scanned: #{result.files_scanned}"
    report << "  Scan time: #{result.scan_time} seconds"
    report << "  Total violations: #{result.total_violations}"
    report << "  Critical: #{result.critical_violations.size}"
    report << "  High: #{result.high_violations.size}"
    report << "  Medium: #{result.medium_violations.size}"
    report << ""

    if result.clean_scan?
      report << "✅ CLEAN SCAN - No violations detected"
      report << "   Domain → ApplicationResult mapping is compliant"
    else
      report << "❌ VIOLATIONS DETECTED"
      report << ""

      # Group by severity
      [:critical, :high, :medium].each do |severity|
        violations = result.send("#{severity}_violations")
        next if violations.empty?

        report << "#{severity.upcase} VIOLATIONS:"
        violations.each do |violation|
          report << "  📁 #{violation.file}:#{violation.line}"
          report << "     #{violation.message}"
          if violation.suggested_fix
            report << "     💡 Suggested fix: #{violation.suggested_fix}"
          end
          report << ""
        end
      end
    end

    report << "=" * 80
    report.join("\n")
  end

  # Default paths to scan
  def self.default_scan_paths
    [
      'app/services/**/*.rb',
      'app/controllers/**/*.rb',
      'lib/services/**/*.rb'
    ]
  end

  # Check if application is ready for Day 3
  def self.ready_for_day3?
    result = scan_application_services
    result.clean_scan?
  end

  # Validate specific violation type
  def self.validate_violation_type(error_type)
    STANDARD_ERROR_TYPES.include?(error_type.to_sym)
  end

  private

  def self.build_violation_message(violation_type, config, match)
    base_message = config[:description]

    # Add context from the match if available
    if match.respond_to?(:pre_match) && match.respond_to?(:post_match)
      context = "#{match.pre_match[-20..-1]}#{match[0]}#{match.post_match[0..20]}"
      "#{base_message}\n   Context: ...#{context}..."
    else
      base_message
    end
  end

  def self.build_suggested_fix(violation_type, match)
    case violation_type
    when :domain_object_exposure
      "Use serializer: ApplicationResult.success(data: Serializer.new.serialize(domain_object))"
    when :domain_exception_propagation
      "Use ApplicationService#execute_with_error_mapping for domain operations"
    when :non_standardized_error_type
      "Use standard error types: #{STANDARD_ERROR_TYPES.join(', ')}"
    when :business_logic_in_controller
      "Move business logic to Application Service layer"
    when :direct_domain_access
      "Use Application Service instead of direct domain access"
    when :service_without_application_result
      "Ensure service call method returns ApplicationResult"
    when :mixed_contract_patterns
      "Return only ApplicationResult, not hash objects"
    else
      "Review Day 3 documentation for proper patterns"
    end
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  require 'fileutils'

  # Parse command line arguments
  options = {
    output: nil,
    paths: nil,
    service_only: false,
    controller_only: false
  }

  ARGV.each_with_index do |arg, index|
    case arg
    when '--output', '-o'
      options[:output] = ARGV[index + 1]
    when '--paths'
      options[:paths] = ARGV[index + 1].split(',')
    when '--services-only'
      options[:service_only] = true
    when '--controllers-only'
      options[:controller_only] = true
    when '--help', '-h'
      puts "Domain Leakage Detector - Step 3.3"
      puts ""
      puts "Usage: ruby domain_leakage_detector.rb [options]"
      puts ""
      puts "Options:"
      puts "  --output, -o <path>    Output report path"
      puts "  --paths <path1,path2>  Custom paths to scan"
      puts "  --services-only        Scan only application services"
      puts "  --controllers-only     Scan only controllers"
      puts "  --help, -h            Show this help"
      puts ""
      puts "Examples:"
      puts "  ruby domain_leakage_detector.rb"
      puts "  ruby domain_leakage_detector.rb --services-only"
      puts "  ruby domain_leakage_detector.rb --output reports/day3/scan.json"
      exit 0
    end
  end

  # Perform scan
  if options[:service_only]
    result = DomainLeakageDetector.scan_application_services
  elsif options[:controller_only]
    result = DomainLeakageDetector.scan_controllers
  else
    result = DomainLeakageDetector.scan_application(options[:paths])
  end

  # Generate report
  report_info = DomainLeakageDetector.generate_report(result, options[:output])

  # Output summary
  puts "Domain Leakage Detection Complete"
  puts "Files scanned: #{result.files_scanned}"
  puts "Violations found: #{result.total_violations}"
  puts "Critical: #{result.critical_violations.size}"
  puts "High: #{result.high_violations.size}"
  puts "Medium: #{result.medium_violations.size}"
  puts ""

  if result.clean_scan?
    puts "✅ CLEAN SCAN - Ready for Day 3 implementation"
  else
    puts "❌ VIOLATIONS DETECTED - Review and fix before proceeding"
    puts "Reports saved:"
    puts "  JSON: #{report_info[:json_report]}"
    puts "  Text: #{report_info[:text_report]}"
    exit 1
  end
end
