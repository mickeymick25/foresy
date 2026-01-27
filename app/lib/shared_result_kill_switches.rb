# Shared::Result Kill-Switches - Day 4 Implementation
# Immediate detection and automatic rejection for Shared::Result violations
# Authority: CTO/Co-CTO Validated
# Date: 2026-01-21

require_relative 'domain_leakage_detector'
require_relative '../lib/application_result'

# WARNING: These kill-switches enforce Day 4 Strangler Rules
# Violations will cause immediate CI failure and production rejection

class SharedResultKillSwitches
  # Kill-switch configuration
  KILL_SWITCH_CONFIG = {
    immediate_failure: true,
    log_violations: true,
    emergency_stop_enabled: true,
    rollback_time_limit: 300, # 5 minutes in seconds
    violation_severity_threshold: 'critical'
  }.freeze

  # Shared::Result violation patterns
  SHARED_RESULT_VIOLATIONS = {
    direct_instantiation: {
      pattern: /Shared::Result\.new|Result\.new|::Result\.new/,
      severity: 'critical',
      message: 'Direct Shared::Result instantiation detected - forbidden in new code',
      kill_switch: true
    },

    direct_import: {
      pattern: /require.*shared.*result|include.*shared.*result/i,
      severity: 'critical',
      message: 'Shared::Result import detected - use ApplicationResult instead',
      kill_switch: true
    },

    custom_adapter: {
      pattern: /class.*Adapter.*<|def.*convert.*result/i,
      severity: 'critical',
      message: 'Custom adapter detected - only official SharedResultAdapter permitted',
      kill_switch: true
    },

    legacy_service_new_code: {
      pattern: /class.*Service.*\n.*Result\.(success|failure)/,
      severity: 'high',
      message: 'Shared::Result usage in new service - adapter required',
      kill_switch: true
    },

    mixed_contracts: {
      pattern: /return\s*\{[^}]*(success|error|data)[^}]*\}/,
      severity: 'high',
      message: 'Mixed contract patterns detected - only ApplicationResult allowed',
      kill_switch: true
    },

    adapter_orchestration: {
      pattern: /Adapter\.(convert|from_shared).*adapter/i,
      severity: 'medium',
      message: 'Adapter orchestration detected - verify official adapter usage',
      kill_switch: false
    }
  }.freeze

  # Organizational kill-switches
  ORGANIZATIONAL_KILL_SWITCHES = {
    rollback_time_limit: {
      condition: -> { rollback_time_exceeded? },
      severity: 'critical',
      message: 'Rollback time limit exceeded - Day 4 FAIL',
      kill_switch: true
    },

    complex_migration_flag: {
      condition: -> { migration_requires_complex_flags? },
      severity: 'high',
      message: 'Migration requires complex feature flags - Day 4 FAIL',
      kill_switch: true
    },

    team_confusion: {
      condition: -> { team_clarity_score_below_threshold? },
      severity: 'high',
      message: 'Team confusion detected about migration patterns - training required',
      kill_switch: false
    },

    migration_drift: {
      condition: -> { migration_patterns_drift_detected? },
      severity: 'medium',
      message: 'Migration pattern drift detected - review required',
      kill_switch: false
    }
  }.freeze

  class KillSwitchViolation
    attr_reader :type, :severity, :message, :source_location, :timestamp, :kill_switch_triggered

    def initialize(type, severity, message, source_location = nil)
      @type = type
      @severity = severity
      @message = message
      @source_location = source_location
      @timestamp = Time.current
      @kill_switch_triggered = KILL_SWITCH_CONFIG[:violation_severity_threshold] == severity
    end

    def critical?
      @severity == 'critical'
    end

    def high?
      @severity == 'high'
    end

    def to_h
      {
        type: @type,
        severity: @severity,
        message: @message,
        source_location: @source_location,
        timestamp: @timestamp.iso8601,
        kill_switch_triggered: @kill_switch_triggered,
        emergency_stop: @kill_switch_triggered
      }
    end

    def to_s
      "#{@severity.upcase} #{@type}: #{@message} (#{@source_location || 'unknown location'})"
    end
  end

  class KillSwitchResult
    attr_reader :violations, :kill_switches_triggered, :emergency_stop, :scan_time

    def initialize
      @violations = []
      @kill_switches_triggered = []
      @emergency_stop = false
      @scan_time = 0
    end

    def add_violation(violation)
      @violations << violation
      if violation.kill_switch_triggered
        @kill_switches_triggered << violation
        @emergency_stop = true if violation.critical?
      end
    end

    def critical_violations
      @violations.select(&:critical?)
    end

    def high_violations
      @violations.select(&:high?)
    end

    def total_violations
      @violations.size
    end

    def clean_scan?
      @violations.empty?
    end

    def to_h
      {
        violations: @violations.map(&:to_h),
        summary: {
          total: total_violations,
          critical: critical_violations.size,
          high: high_violations.size,
          kill_switches_triggered: @kill_switches_triggered.size,
          emergency_stop: @emergency_stop,
          scan_time: @scan_time
        },
        kill_switches_triggered: @kill_switches_triggered.map(&:to_h),
        timestamp: Time.current.iso8601
      }
    end

    def to_json
      JSON.pretty_generate(to_h)
    end
  end

  # Main detection methods
  def self.detect_shared_result_violations(code_content, file_path = "unknown")
    violations = []
    start_time = Time.current

    SHARED_RESULT_VIOLATIONS.each do |violation_type, config|
      pattern = config[:pattern]
      matches = code_content.enum_for(:scan, pattern).map { Regexp.last_match }

      matches.each do |match|
        source_location = "#{file_path}:#{match.begin(0)}"

        violation = KillSwitchViolation.new(
          violation_type,
          config[:severity],
          config[:message],
          source_location
        )

        violations << violation

        # Log violation if configured
        if KILL_SWITCH_CONFIG[:log_violations]
          Rails.logger.error "🚨 Shared::Result Kill-Switch Violation: #{violation.to_s}"
        end
      end
    end

    violations
  end

  # Scan file for violations
  def self.scan_file(file_path)
    return [] unless File.exist?(file_path)

    content = File.read(file_path)
    detect_shared_result_violations(content, file_path)
  end

  # Scan multiple files
  def self.scan_files(file_paths)
    result = KillSwitchResult.new
    start_time = Time.current

    file_paths.each do |file_path|
      next unless File.exist?(file_path)

      violations = scan_file(file_path)
      violations.each { |v| result.add_violation(v) }
    end

    result.scan_time = (Time.current - start_time).round(2)
    result
  end

  # Scan application for Shared::Result violations
  def self.scan_application(paths = nil)
    paths ||= default_scan_paths

    result = KillSwitchResult.new
    start_time = Time.current

    paths.each do |path|
      if File.directory?(path)
        files = Dir.glob("#{path}/**/*.rb")
        files.each do |file|
          violations = scan_file(file)
          violations.each { |v| result.add_violation(v) }
        end
      elsif File.exist?(path)
        violations = scan_file(path)
        violations.each { |v| result.add_violation(v) }
      end
    end

    result.scan_time = (Time.current - start_time).round(2)
    result
  end

  # Organizational kill-switch checks
  def self.check_organizational_kill_switches
    violations = []

    ORGANIZATIONAL_KILL_SWITCHES.each do |kill_switch_type, config|
      if config[:condition].call
        violation = KillSwitchViolation.new(
          kill_switch_type,
          config[:severity],
          config[:message],
          "organizational_check"
        )
        violations << violation
      end
    end

    violations
  end

  # Comprehensive scan including organizational checks
  def self.comprehensive_scan
    result = scan_application
    organizational_violations = check_organizational_kill_switches

    organizational_violations.each { |v| result.add_violation(v) }

    result
  end

  # Emergency stop procedures
  def self.emergency_stop(reason = "Kill-switch triggered")
    return unless KILL_SWITCH_CONFIG[:emergency_stop_enabled]

    Rails.logger.error "🚨 DAY 4 EMERGENCY STOP TRIGGERED: #{reason}"

    # Log emergency stop
    File.open('log/day4_emergency.log', 'a') do |log|
      log.puts "#{Time.current.iso8601} - EMERGENCY STOP: #{reason}"
      log.puts "Active violations: #{comprehensive_scan.total_violations}"
      log.puts "Kill-switches triggered: #{comprehensive_scan.kill_switches_triggered.size}"
    end

    # Notify on-call team
    notify_emergency_team(reason)

    # Trigger rollback if needed
    trigger_emergency_rollback if reason.include?('rollback')
  end

  def self.notify_emergency_team(reason)
    # Integration with monitoring/alerting system
    message = "Day 4 Kill-Switch Emergency Stop: #{reason}"

    # This would integrate with your notification system (Slack, PagerDuty, etc.)
    Rails.logger.error "🚨 EMERGENCY NOTIFICATION: #{message}"

    # Example integration points:
    # SlackNotificationService.send(message)
    # PagerDutyService.trigger_incident(message)
  end

  def self.trigger_emergency_rollback
    Rails.logger.error "🧯 TRIGGERING EMERGENCY ROLLBACK"

    # This would trigger your rollback procedure
    rollback_result = system("bundle exec rake day4_emergency:rollback_shared_result")

    if rollback_result
      Rails.logger.info "✅ Emergency rollback completed successfully"
    else
      Rails.logger.error "❌ Emergency rollback failed - manual intervention required"
    end
  end

  # CI/CD Integration helpers
  def self.validate_for_ci(file_paths)
    result = scan_files(file_paths)

    if result.emergency_stop
      puts "🚨 KILL-SWITCH TRIGGERED - EMERGENCY STOP"
      puts "Critical violations detected: #{result.critical_violations.size}"
      result.critical_violations.each do |violation|
        puts "  #{violation.to_s}"
      end
      exit 1 # Fail CI build
    elsif result.total_violations > 0
      puts "⚠️ VIOLATIONS DETECTED - REVIEW REQUIRED"
      puts "Total violations: #{result.total_violations}"
      result.violations.each do |violation|
        puts "  #{violation.to_s}"
      end
      exit 1 # Fail CI build for violations
    else
      puts "✅ Shared::Result Kill-Switches PASSED"
    end

    result
  end

  # Pre-commit hook integration
  def self.pre_commit_check
    # Get changed files from git
    changed_files = `git diff --cached --name-only`.split("\n").select { |f| f.end_with?('.rb') }

    if changed_files.empty?
      puts "✅ No Ruby files changed - Shared::Result check skipped"
      return true
    end

    result = scan_files(changed_files)

    if result.emergency_stop
      puts "🚨 EMERGENCY STOP - Cannot proceed with commit"
      puts "Critical Shared::Result violations detected"
      result.critical_violations.each { |v| puts "  #{v.to_s}" }
      return false
    elsif result.total_violations > 0
      puts "⚠️ Shared::Result violations detected - fix before committing"
      result.violations.each { |v| puts "  #{v.to_s}" }
      return false
    end

    puts "✅ Shared::Result Kill-Switches passed"
    true
  end

  # Migration progress tracking
  def self.track_migration_progress(service_class)
    progress_file = "tmp/day4_migration_progress.json"

    progress_data = if File.exist?(progress_file)
      JSON.parse(File.read(progress_file))
    else
      { services: {}, total_services: 0, migrated_services: 0 }
    end

    service_name = service_class.name || 'Unknown'

    # Check if service uses adapter
    source_location = service_class.instance_method(:call).source_location
    if source_location
      source_code = File.read(source_location[0])
      uses_adapter = source_code.include?('SharedResultAdapter') || source_code.include?('from_shared')
      uses_shared_result = source_code.match?(/Result\.(success|failure)/)

      progress_data['services'][service_name] = {
        adapter_usage: uses_adapter,
        shared_result_usage: uses_shared_result,
        last_check: Time.current.iso8601
      }
    end

    progress_data['total_services'] = progress_data['services'].size
    progress_data['migrated_services'] = progress_data['services'].count { |_, data| data['adapter_usage'] }

    File.write(progress_file, JSON.pretty_generate(progress_data))

    {
      total: progress_data['total_services'],
      migrated: progress_data['migrated_services'],
      percentage: progress_data['total_services'] > 0 ? (progress_data['migrated_services'].to_f / progress_data['total_services'] * 100).round(1) : 0
    }
  end

  # Rollback time tracking
  def self.start_rollback_timer
    File.write('tmp/day4_rollback_start.txt', Time.current.iso8601)
  end

  def self.rollback_time_exceeded?
    return false unless File.exist?('tmp/day4_rollback_start.txt')

    start_time = File.read('tmp/day4_rollback_start.txt')
    elapsed_time = Time.current - Time.parse(start_time)

    elapsed_time > KILL_SWITCH_CONFIG[:rollback_time_limit]
  end

  def self.reset_rollback_timer
    File.delete('tmp/day4_rollback_start.txt') if File.exist?('tmp/day4_rollback_start.txt')
  end

  # Team clarity assessment
  def self.assess_team_clarity
    # This would integrate with your team's tools to assess understanding
    # Examples: survey responses, code review feedback, support tickets

    clarity_score = calculate_clarity_score_from_indicators

    {
      score: clarity_score,
      level: clarity_score > 80 ? 'clear' : clarity_score > 60 ? 'mostly_clear' : 'confused',
      indicators: collect_clarity_indicators
    }
  end

  def self.team_clarity_score_below_threshold?
    assessment = assess_team_clarity
    assessment[:score] < 70 # Threshold for confusion
  end

  # Migration drift detection
  def self.detect_migration_drift
    # Analyze recent commits for pattern drift
    recent_commits = `git log --oneline -20`.split("\n")

    drift_indicators = []

    recent_commits.each do |commit|
      commit_message = commit.downcase
      if commit_message.include?('shared_result') || commit_message.include?('adapter')
        drift_indicators << commit if commit_message.include?('fix') || commit_message.include?('workaround')
      end
    end

    drift_indicators.size > 3 # Threshold for drift detection
  end

  def self.migration_patterns_drift_detected?
    detect_migration_drift
  end

  # Report generation
  def self.generate_kill_switch_report(result, output_path = nil)
    output_path ||= "outputs/reports/day4/kill_switches_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"

    FileUtils.mkdir_p(File.dirname(output_path))

    # Generate detailed report
    report_data = {
      scan_info: {
        timestamp: Time.current.iso8601,
        kill_switches_version: '1.0',
        authority: 'Day 4 CTO/Co-CTO Validated'
      },
      scan_results: result.to_h,
      migration_progress: track_migration_progress_progress,
      team_clarity: assess_team_clarity,
      recommendations: generate_recommendations(result)
    }

    File.write(output_path, JSON.pretty_generate(report_data))

    # Also generate human-readable summary
    summary_path = output_path.sub('.json', '_summary.txt')
    File.write(summary_path, generate_text_summary(report_data))

    {
      json_report: output_path,
      text_summary: summary_path,
      result: result
    }
  end

  # Helper methods
  def self.default_scan_paths
    [
      'app/services/**/*.rb',
      'app/controllers/**/*.rb',
      'lib/**/*.rb'
    ]
  end

  def self.calculate_clarity_score_from_indicators
    # This would analyze various indicators from your team's tools
    # Placeholder implementation
    85 # Default to good score
  end

  def self.collect_clarity_indicators
    # Collect various clarity indicators
    {
      support_tickets: 0,
      code_review_questions: 2,
      documentation_views: 15,
      adapter_usage_questions: 1
    }
  end

  def self.generate_recommendations(result)
    recommendations = []

    if result.critical_violations.any?
      recommendations << "Address critical Shared::Result violations immediately"
      recommendations << "Implement official SharedResultAdapter for migration"
    end

    if result.high_violations.any?
      recommendations << "Review high-severity violations and plan remediation"
    end

    recommendations << "Continue monitoring migration progress"
    recommendations << "Maintain team training on Day 4 patterns"

    recommendations
  end

  def self.generate_text_summary(report_data)
    summary = []
    summary << "=" * 80
    summary << "DAY 4 KILL-SWITCHES REPORT"
    summary << "=" * 80
    summary << ""
    summary << "Generated: #{report_data[:scan_info][:timestamp]}"
    summary << "Authority: #{report_data[:scan_info][:authority]}"
    summary << ""

    results = report_data[:scan_results]
    summary << "SCAN SUMMARY:"
    summary << "  Total violations: #{results[:summary][:total]}"
    summary << "  Critical: #{results[:summary][:critical]}"
    summary << "  High: #{results[:summary][:high]}"
    summary << "  Kill-switches triggered: #{results[:summary][:kill_switches_triggered]}"
    summary << "  Emergency stop: #{results[:summary][:emergency_stop]}"
    summary << ""

    if results[:violations].any?
      summary << "VIOLATIONS:"
      results[:violations].each do |violation|
        summary << "  #{violation[:severity].upcase} #{violation[:type]}: #{violation[:message]}"
        summary << "    Location: #{violation[:source_location]}"
        summary << ""
      end
    else
      summary << "✅ CLEAN SCAN - No Shared::Result violations detected"
    end

    summary << "=" * 80
    summary.join("\n")
  end

  # Private methods for internal calculations
  def self.track_migration_progress_progress
    # Placeholder for migration progress tracking
    { total: 0, migrated: 0, percentage: 0 }
  end

  def self.migration_requires_complex_flags?
    # Check if migration would require complex feature flags
    # This would analyze the codebase for flag usage
    false # Placeholder
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  require 'fileutils'

  options = {
    output: nil,
    paths: nil,
    emergency_stop: false,
    pre_commit: false
  }

  OptionParser.new do |parser|
    parser.banner = "Usage: ruby shared_result_kill_switches.rb [options]"

    parser.on('--output PATH', 'Output report path') do |path|
      options[:output] = path
    end

    parser.on('--paths PATHS', 'Custom paths to scan (comma-separated)') do |paths|
      options[:paths] = paths.split(',')
    end

    parser.on('--emergency-stop REASON', 'Trigger emergency stop') do |reason|
      options[:emergency_stop] = true
      options[:reason] = reason
    end

    parser.on('--pre-commit', 'Run pre-commit check') do
      options[:pre_commit] = true
    end

    parser.on('--help', 'Show this help') do
      puts parser
      puts ""
      puts "Commands:"
      puts "  ruby shared_result_kill_switches.rb --pre-commit"
      puts "  ruby shared_result_kill_switches.rb --emergency-stop 'violation reason'"
      puts "  ruby shared_result_kill_switches.rb --output reports/day4/kill_switches.json"
      exit 0
    end
  end.parse!

  # Execute based on options
  if options[:emergency_stop]
    SharedResultKillSwitches.emergency_stop(options[:reason] || "Manual emergency stop")
  elsif options[:pre_commit]
    success = SharedResultKillSwitches.pre_commit_check
    exit(success ? 0 : 1)
  else
    # Run comprehensive scan
    paths = options[:paths] || SharedResultKillSwitches.default_scan_paths
    result = SharedResultKillSwitches.comprehensive_scan

    report_info = SharedResultKillSwitches.generate_kill_switch_report(result, options[:output])

    puts "Day 4 Kill-Switches Scan Complete"
    puts "Files scanned: #{paths.size}"
    puts "Violations found: #{result.total_violations}"
    puts "Critical: #{result.critical_violations.size}"
    puts "High: #{result.high_violations.size}"
    puts "Kill-switches triggered: #{result.kill_switches_triggered.size}"

    if result.emergency_stop
      puts "🚨 EMERGENCY STOP TRIGGERED"
      exit 1
    elsif result.total_violations > 0
      puts "⚠️ VIOLATIONS DETECTED - Review required"
      exit 1
    else
      puts "✅ KILL-SWITCHES PASSED"
    end
  end
end
