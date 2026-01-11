# frozen_string_literal: true

# SimpleCov configuration for coverage tracking
require 'simplecov'
require 'simplecov_json_formatter'

# Start SimpleCov before any other code loads
SimpleCov.start do
  # Add filters to exclude files from coverage
  add_filter '/spec/'
  add_filter '/vendor/'
  add_filter '/config/'
  add_filter '/db/'
  add_filter '/script/'
  add_filter 'app/jobs/application_job.rb'
  add_filter 'app/mailers/application_mailer.rb'
  add_filter 'app/channels/application_cable/'
  add_filter 'lib/tasks/'

  # Configure coverage tracking
  track_files '**/*.rb'

  # Minimum coverage thresholds - ACTIVATED per PR15 Plan
  minimum_coverage 90.0 # Overall coverage must be >= 90% (PR15 Standard)
  minimum_coverage_by_file 80.0 # Per-file coverage must be >= 80% (PR15 Standard)

  # Use JSON formatter for CI integration
  formatter SimpleCov::Formatter::JSONFormatter

  # Enable branch coverage tracking
  enable_coverage :branch

  # Ignore errors during coverage generation
  # ignore_errors true  # Removed - not a valid SimpleCov method
end

# Helper module for coverage validation - PR15 Implementation
module CoverageHelper
  def self.ensure_minimum_coverage!
    return unless ENV['CI']

    # Get SimpleCov results directly instead of parsing JSON file
    if defined?(SimpleCov) && SimpleCov.result
      result = SimpleCov.result
      total_coverage = result.covered_percent

      # Check overall coverage
      if total_coverage < 90.0
        raise "❌ COVERAGE FAILURE: #{total_coverage.round(2)}% is below minimum 90.0%\n" +
              "Required: 90.0%, Actual: #{total_coverage.round(2)}%, Missing: #{(90.0 - total_coverage).round(2)}%"
      end

      # Check per-file coverage (minimum 80%)
      files_below_threshold = result.files.select do |file|
        file.covered_percent < 80.0
      end

      if files_below_threshold.any?
        file_list = files_below_threshold.first(5).map { |f| "#{f.filename}: #{f.covered_percent.round(2)}%" }.join(', ')
        raise "❌ FILE COVERAGE FAILURE: #{files_below_threshold.count} files below 80% threshold\n" +
              "Examples: #{file_list}..."
      end

      puts "✅ Coverage requirement met: #{total_coverage.round(2)}% (>= 90.0%)"
      puts "✅ All files meet minimum 80% coverage threshold"

      # Generate coverage report for CI
      File.write('coverage/coverage.json', result.to_json)
    else
      raise "❌ SimpleCov results not available - coverage validation failed"
    end
  rescue StandardError => e
    # Always fail CI on coverage issues
    puts "❌ COVERAGE VALIDATION ERROR: #{e.message}"
    raise e
  end
end

# Configure RSpec
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # Validate coverage after test suite completes - PR15 Critical Validation
  config.after(:suite) do
    CoverageHelper.ensure_minimum_coverage!
  end
end
