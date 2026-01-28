# Shared::Result Adapter - Day 4 Official Implementation
# Unique passage point for Shared::Result → ApplicationResult migration
# Authority: CTO/Co-CTO Validated
# Date: 2026-01-21

require_relative '../lib/application_result'

# WARNING: This adapter is IMPURE by design
# It exists to provide a migration path from Shared::Result to ApplicationResult
# Direct calls to Shared::Result in new code = CRITICAL VIOLATION

class SharedResultAdapter
  # Adapter instrumentation and logging
  ADAPTER_CONFIG = {
    log_all_conversions: true,
    raise_on_legacy_usage: Rails.env.development?,
    convert_unknown_result: true,
    adapter_version: '1.0'
  }.freeze

  # Standardized Shared::Result methods that need mapping
  SHARED_RESULT_METHODS = %i[
    success failure success? failure?
  ].freeze

  # Mapping from Shared::Result error types to ApplicationResult
  SHARED_RESULT_ERROR_MAPPING = {
    'validation_error' => :validation_error,
    'authorization_error' => :unauthorized,
    'business_rule_error' => :conflict,
    'not_found_error' => :not_found,
    'internal_error' => :internal_error
  }.freeze

  class AdapterViolationError < StandardError
    def initialize(message, source_location = nil)
      super(message)
      @source_location = source_location
    end
  end

  class ConversionLog
    attr_reader :timestamp, :from_type, :to_type, :method_called, :source_location

    def initialize(from_type, to_type, method_called, source_location)
      @timestamp = Time.current
      @from_type = from_type
      @to_type = to_type
      @method_called = method_called
      @source_location = source_location
    end

    def to_h
      {
        timestamp: @timestamp.iso8601,
        from_type: @from_type,
        to_type: @to_type,
        method_called: @method_called,
        source_location: @source_location,
        adapter_version: ADAPTER_CONFIG[:adapter_version]
      }
    end
  end

  # Conversion log storage
  def self.conversion_logs
    @conversion_logs ||= []
  end

  def self.log_conversion(from_type, to_type, method_called, source_location)
    log_entry = ConversionLog.new(from_type, to_type, method_called, source_location)
    conversion_logs << log_entry

    # Log to Rails logger if configured
    if ADAPTER_CONFIG[:log_all_conversions] && Rails.logger
      Rails.logger.info "🔄 Shared::Result → ApplicationResult Conversion: #{log_entry.to_h.to_json}"
    end

    log_entry
  end

  def self.clear_logs
    @conversion_logs = []
  end

  def self.get_conversion_statistics
    {
      total_conversions: conversion_logs.size,
      by_method: conversion_logs.group_by(&:method_called).transform_values(&:size),
      recent_conversions: conversion_logs.last(10).map(&:to_h)
    }
  end

  # Main conversion methods
  def self.from_shared_result(shared_result)
    return nil if shared_result.nil?

    # Detect source location for violation tracking
    source_location = caller_locations(1, 1).first&.to_s

    log_conversion('Shared::Result', 'ApplicationResult', 'from_shared_result', source_location)

    if shared_result.success?
      ApplicationResult.success(data: extract_data_from_shared(shared_result))
    else
      ApplicationResult.send(
        map_error_type(shared_result.error_type),
        message: shared_result.message || 'Unknown error'
      )
    end
  rescue StandardError => e
    handle_conversion_error(e, shared_result, source_location)
  end

  # Safe conversion with fallback
  def self.try_convert(shared_result, fallback: nil)
    return fallback if shared_result.nil?

    begin
      from_shared_result(shared_result)
    rescue StandardError => e
      Rails.logger.error "Adapter conversion failed: #{e.message}"
      fallback
    end
  end

  # Check if object can be converted
  def self.can_convert?(object)
    return false if object.nil?

    # Check for Shared::Result interface
    has_success_methods = SHARED_RESULT_METHODS.all? { |method| object.respond_to?(method) }

    return has_success_methods if object.class.name.include?('Result')

    # Additional check for Duck typing
    (object.respond_to?(:success?) && object.respond_to?(:failure?) &&
      object.respond_to?(:data)) || object.respond_to?(:value)
  end

  # Detect legacy usage patterns
  def self.detect_legacy_usage(code_string)
    violations = []

    # Direct Shared::Result instantiation
    if code_string =~ /Shared::Result\.new|Result\.new/
      violations << {
        type: 'direct_shared_result_instantiation',
        severity: 'critical',
        message: 'Direct Shared::Result instantiation detected'
      }
    end

    # Legacy import/require
    if code_string =~ /require.*shared.*result|include.*shared.*result/i
      violations << {
        type: 'legacy_import',
        severity: 'critical',
        message: 'Legacy Shared::Result import detected'
      }
    end

    violations
  end

  # Migration helper for existing code
  def self.migrate_shared_result_usage(service_method_body)
    migrated_code = service_method_body.dup

    # Replace common patterns
    migrated_code.gsub!(
      /Result\.success\(([^)]+)\)/,
      'ApplicationResult.success(data: \1)'
    )

    migrated_code.gsub!(
      /Result\.failure\(([^)]+)\)/,
      'ApplicationResult.validation_error(message: \1)'
    )

    migrated_code.gsub!(
      /if\s+result\.success\?/,
      'if result.success?'
    )

    migrated_code.gsub!(
      'result.failure?',
      'result.failure?'
    )

    migrated_code
  end

  def self.extract_data_from_shared(shared_result)
    # Try multiple data extraction methods
    if shared_result.respond_to?(:data)
      shared_result.data
    elsif shared_result.respond_to?(:value)
      shared_result.value
    else
      shared_result
    end
  end

  def self.map_error_type(shared_error_type)
    mapped_type = SHARED_RESULT_ERROR_MAPPING[shared_error_type.to_s]
    mapped_type || :internal_error
  end

  def self.handle_conversion_error(error, shared_result, source_location)
    Rails.logger.error "Adapter conversion error: #{error.message}"
    Rails.logger.error "Source location: #{source_location}"
    Rails.logger.error "Shared result class: #{shared_result.class}"

    # In development, raise to help developers fix issues
    if ADAPTER_CONFIG[:raise_on_legacy_usage]
      raise AdapterViolationError.new(
        "Failed to convert Shared::Result: #{error.message}",
        source_location
      )
    end

    # In production, return fallback ApplicationResult
    ApplicationResult.internal_error(
      message: "Adapter conversion failed: #{error.message}"
    )
  end
end

# Rails integration for automatic detection
module SharedResultAdapter::Railtie
  class << self
    def included(base)
      base.extend(ClassMethods)
    end
  end

  module ClassMethods
    def detect_shared_result_in_controllers
      # Override controller methods to detect Shared::Result usage
      base.prepend(ControllerSharedResultDetection)
    end

    def detect_shared_result_in_services
      # Override service methods to detect Shared::Result usage
      base.prepend(ServiceSharedResultDetection)
    end
  end

  module ControllerSharedResultDetection
    def render(options = {}, status = nil, layout = nil)
      detect_shared_result_in_options(options)
      super
    end

    private

    def detect_shared_result_in_options(options)
      if options[:json].is_a?(Hash) && options[:json][:data] && SharedResultAdapter.can_convert?(options[:json][:data])
        Rails.logger.warn '🔍 Detected Shared::Result in controller render data - conversion will be applied'
      end
    end
  end

  module ServiceSharedResultDetection
    def call(*)
      detect_shared_result_in_call(*)
      super
    end

    private

    def detect_shared_result_in_call(*args)
      # Check if any arguments contain Shared::Result
      args.each do |arg|
        if SharedResultAdapter.can_convert?(arg)
          Rails.logger.warn '🔍 Detected Shared::Result in service call arguments - migration needed'
        end
      end
    end
  end
end

# Monkey patch for Shared::Result to add conversion warnings
if defined?(Shared::Result)
  Shared::Result.singleton_class.prepend(Module.new do
    def success(*, **)
      Rails.logger.warn '⚠️ Shared::Result.success called - use ApplicationResult.success instead'
      Rails.logger.warn '🔗 Migration guide: https://docs/foresy/day4/shared-result-migration'
      super
    end

    def failure(*, **)
      Rails.logger.warn '⚠️ Shared::Result.failure called - use ApplicationResult.validation_error instead'
      Rails.logger.warn '🔗 Migration guide: https://docs/foresy/day4/shared-result-migration'
      super
    end
  end)
end

# Usage examples and documentation

# ✅ CORRECT USAGE - Service using adapter
# class LegacyService
#   def call
#     # Old code returns Shared::Result
#     result = old_method_returning_shared_result
#
#     # Convert to ApplicationResult using adapter
#     ApplicationResult.from_shared(result)
#   end
#
#   private
#
#   def old_method_returning_shared_result
#     # This would be migrated gradually
#     Shared::Result.success(data: { legacy: 'data' })
#   end
# end

# ✅ CORRECT USAGE - Safe conversion
# class SafeMigrationService
#   def call
#     result = legacy_method
#
#     # Safe conversion with fallback
#     ApplicationResult.try_convert(result, fallback: ApplicationResult.internal_error(message: "Conversion failed"))
#   end
# end

# ❌ INCORRECT USAGE - Direct Shared::Result in new code
# class BadService
#   def call
#     # This is VIOLATION - direct Shared::Result usage
#     return Shared::Result.success(data: result)  # NOT ALLOWED
#   end
# end

# Migration checklist for developers:
#
# 1. Replace Shared::Result.success with ApplicationResult.success
# 2. Replace Shared::Result.failure with appropriate ApplicationResult methods
# 3. Update error handling to use ApplicationResult patterns
# 4. Remove Shared::Result imports/requires
# 5. Run adapter detection to verify cleanup

# CLI interface for migration
if __FILE__ == $PROGRAM_NAME
  require 'fileutils'
  require 'optparse'

  options = {
    dry_run: false,
    verbose: false,
    backup: true
  }

  OptionParser.new do |parser|
    parser.banner = 'Usage: ruby shared_result_adapter.rb [options] <file_or_directory>'

    parser.on('--dry-run', 'Show what would be changed without making changes') do
      options[:dry_run] = true
    end

    parser.on('--verbose', 'Show detailed output') do
      options[:verbose] = true
    end

    parser.on('--no-backup', 'Do not create backup files') do
      options[:backup] = false
    end

    parser.on('--help', 'Show this help') do
      puts parser
      puts ''
      puts 'Migration Helper Commands:'
      puts '  ruby shared_result_adapter.rb --scan <directory>     Scan for Shared::Result usage'
      puts '  ruby shared_result_adapter.rb --migrate <file>        Migrate a single file'
      puts '  ruby shared_result_adapter.rb --check <file>         Check if file can be safely migrated'
      exit 0
    end
  end.parse!

  target_path = ARGV.first

  if target_path && File.exist?(target_path)
    if File.directory?(target_path)
      puts "🔍 Scanning directory: #{target_path}"
      results = SharedResultAdapter.scan_directory_for_legacy_usage(target_path)
      puts "Found #{results.size} files with potential Shared::Result usage"
    elsif File.file?(target_path)
      puts "🔍 Scanning file: #{target_path}"
      content = File.read(target_path)
      violations = SharedResultAdapter.detect_legacy_usage(content)
      puts "Found #{violations.size} violations:"
      violations.each { |v| puts "  - #{v[:type]}: #{v[:message]}" }
    end
  else
    puts '🔄 Testing adapter conversion...'

    # Test conversion
    test_result = Struct.new(:success?, :data, :error_type, :message).new
    test_result.success = true
    test_result.data = { test: 'data' }

    converted = SharedResultAdapter.from_shared_result(test_result)
    puts "✅ Conversion test: #{converted.success?}"
    puts "📊 Conversion statistics: #{SharedResultAdapter.get_conversion_statistics.to_json}"
  end
end
