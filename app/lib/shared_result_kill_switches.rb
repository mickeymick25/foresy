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
      condition: -> { KillSwitchMigrator.rollback_time_exceeded? },
      severity: 'critical',
      message: 'Rollback time limit exceeded - Day 4 FAIL',
      kill_switch: true
    },

    complex_migration_flag: {
      condition: -> { KillSwitchMigrator.migration_requires_complex_flags? },
      severity: 'high',
      message: 'Migration requires complex feature flags - Day 4 FAIL',
      kill_switch: true
    },

    team_confusion: {
      condition: -> { KillSwitchEvaluator.team_clarity_score_below_threshold? },
      severity: 'high',
      message: 'Team confusion detected about migration patterns - training required',
      kill_switch: false
    },

    migration_drift: {
      condition: -> { KillSwitchEvaluator.migration_patterns_drift_detected? },
      severity: 'medium',
      message: 'Migration pattern drift detected - review required',
      kill_switch: false
    }
  }.freeze

  class KillSwitchViolation
    attr_reader :type, :severity, :message, :source_location, :timestamp, :kill_switch_triggered

    def initialize(type, severity, message, source_location, kill_switch_triggered: false)
      @type = type
      @severity = severity
      @message = message
      @source_location = source_location
      @timestamp = Time.current
      @kill_switch_triggered = kill_switch_triggered
    end

    def critical?
      severity == 'critical'
    end

    def high?
      severity == 'high'
    end

    def to_h
      {
        type: @type,
        severity: @severity,
        message: @message,
        source_location: @source_location,
        timestamp: @timestamp,
        kill_switch_triggered: @kill_switch_triggered
      }
    end

    def to_s
      "[#{@severity.upcase}] #{@message} at #{@source_location}"
    end
  end

  class KillSwitchResult
    attr_reader :violations, :kill_switches_triggered, :emergency_stop, :scan_time

    def initialize(violations = [], kill_switches_triggered = [], emergency_stop: false)
      @violations = violations
      @kill_switches_triggered = kill_switches_triggered
      @emergency_stop = emergency_stop
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

    def total_violations
      @violations.size
    end

    def clean_scan?
      @violations.empty?
    end

    def to_h
      {
        violations: @violations.map(&:to_h),
        kill_switches_triggered: @kill_switches_triggered,
        emergency_stop: @emergency_stop,
        scan_time: @scan_time,
        summary: {
          total: total_violations,
          critical: critical_violations.size,
          high: high_violations.size,
          clean_scan: clean_scan?
        }
      }
    end

    def to_json(*_args)
      require 'json'
      JSON.pretty_generate(to_h)
    end
  end
end

class KillSwitchDetector < SharedResultKillSwitches
  def self.detect_shared_result_violations(code_content, file_path = 'unknown')
    violations = []

    SHARED_RESULT_VIOLATIONS.each do |violation_type, config|
      pattern = config[:pattern]
      matches = code_content.enum_for(:scan, pattern).map { Regexp.last_match }

      matches.each do |match|
        message = config[:message]
        kill_switch = config[:kill_switch] || false

        violations << KillSwitchViolation.new(
          violation_type,
          config[:severity],
          message,
          "#{file_path}:#{match.begin(0)}",
          kill_switch_triggered: kill_switch
        )
      end
    end

    violations
  end

  def self.scan_file(file_path)
    return [] unless File.exist?(file_path)

    content = File.read(file_path)
    detect_shared_result_violations(content, file_path)
  end

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

  def self.scan_application(paths = nil)
    paths ||= default_scan_paths

    result = KillSwitchResult.new
    start_time = Time.current

    paths.each do |path|
      if File.directory?(path)
        files = Dir.glob("#{path}/**/*.rb")
        violations = scan_files(files)
        violations.violations.each { |v| result.add_violation(v) }
      elsif File.exist?(path)
        violations = scan_file(path)
        violations.each { |v| result.add_violation(v) }
      end
    end

    result.scan_time = (Time.current - start_time).round(2)
    result
  end

  def self.check_organizational_kill_switches
    triggered = []

    ORGANIZATIONAL_KILL_SWITCHES.each do |kill_switch_name, config|
      next unless config[:condition].call

      triggered << {
        name: kill_switch_name,
        severity: config[:severity],
        message: config[:message],
        kill_switch: config[:kill_switch]
      }
    end

    triggered
  end

  def self.comprehensive_scan(paths = nil)
    # Scan for Shared::Result violations
    code_scan_result = scan_application(paths)

    # Check organizational kill switches
    organizational_violations = check_organizational_kill_switches

    # Combine results
    all_violations = code_scan_result.violations + organizational_violations.map do |v|
      KillSwitchViolation.new(
        v[:name],
        v[:severity],
        v[:message],
        'organizational_check',
        kill_switch_triggered: v[:kill_switch]
      )
    end

    result = KillSwitchResult.new(all_violations)
    result.scan_time = code_scan_result.scan_time
    result.kill_switches_triggered = organizational_violations.select { |v| v[:kill_switch] }
    result.emergency_stop = organizational_violations.any? { |v| v[:kill_switch] && v[:severity] == 'critical' }

    result
  end

  def self.default_scan_paths
    [
      'app/**/*.rb',
      'lib/**/*.rb',
      'spec/**/*.rb'
    ]
  end
end

class KillSwitchValidator < SharedResultKillSwitches
  def self.emergency_stop
    # Check if any critical organizational kill switches are triggered
    check_organizational_kill_switches.any? do |violation|
      violation[:severity] == 'critical' && violation[:kill_switch]
    end
  end

  def self.notify_emergency_team(violation_info)
    # Placeholder for emergency notification system
    # In real implementation, this would send alerts to the team
    puts "🚨 EMERGENCY: #{violation_info[:message]}"
    puts "   Severity: #{violation_info[:severity]}"
    puts "   Kill Switch: #{violation_info[:kill_switch]}"
    puts "   Time: #{Time.current}"
  end

  def self.trigger_emergency_rollback(result)
    if result.emergency_stop
      # Trigger rollback procedure
      KillSwitchMigrator.start_rollback_timer

      # Notify team
      notify_emergency_team({
                              severity: 'critical',
                              message: 'Emergency rollback triggered - CI/CD pipeline halted',
                              kill_switch: true,
                            })

      true
    else
      false
    end
  end

  def self.validate_for_ci(paths = nil)
    result = KillSwitchDetector.comprehensive_scan(paths)

    if result.emergency_stop
      trigger_emergency_rollback(result)
      return {
        passed: false,
        reason: 'Emergency stop triggered - critical violations detected',
        result: result
      }
    end

    critical_count = result.critical_violations.size
    if critical_count.positive?
      return {
        passed: false,
        reason: "#{critical_count} critical violations detected",
        result: result
      }
    end

    {
      passed: true,
      result: result
    }
  end

  def self.pre_commit_check(paths = nil)
    result = KillSwitchDetector.comprehensive_scan(paths)

    if result.emergency_stop
      puts '❌ PRE-COMMIT CHECK FAILED: Emergency stop triggered'
      puts '   Critical organizational violations detected'
      puts '   Please resolve before committing'
      return false
    end

    if result.total_violations.positive?
      puts "⚠️  PRE-COMMIT CHECK WARNING: #{result.total_violations} violations detected"
      result.critical_violations.each do |violation|
        puts "   CRITICAL: #{violation.message}"
      end
      puts '   Consider fixing these violations before committing'
      return false
    end

    puts '✅ PRE-COMMIT CHECK PASSED: No Shared::Result violations'
    true
  end
end

class KillSwitchMigrator < SharedResultKillSwitches
  def self.track_migration_progress
    # Track migration progress indicators
    {
      services_migrated: count_migrated_services,
      controllers_migrated: count_migrated_controllers,
      adapters_created: count_created_adapters,
      violations_remaining: count_remaining_violations,
      migration_score: calculate_migration_score
    }
  end

  def self.start_rollback_timer
    @rollback_start_time = Time.current
  end

  def self.rollback_time_exceeded?
    return false unless @rollback_start_time

    time_elapsed = (Time.current - @rollback_start_time).to_i
    time_elapsed > KILL_SWITCH_CONFIG[:rollback_time_limit]
  end

  def self.reset_rollback_timer
    @rollback_start_time = nil
  end

  def self.migration_requires_complex_flags?
    # Check if migration requires complex feature flags
    violations = KillSwitchDetector.comprehensive_scan
    complex_patterns = violations.select do |v|
      v.message.include?('complex') || v.message.include?('multiple')
    end

    complex_patterns.size > 3
  end
end

class KillSwitchEvaluator < SharedResultKillSwitches
  def self.assess_team_clarity
    # Assess team clarity on migration patterns
    indicators = collect_clarity_indicators
    score = calculate_clarity_score_from_indicators(indicators)

    {
      score: score,
      indicators: indicators,
      assessment: score < 0.7 ? 'confused' : 'clear'
    }
  end

  def self.team_clarity_score_below_threshold?
    assessment = assess_team_clarity
    assessment[:score] < 0.7
  end

  def self.detect_migration_drift
    # Detect if migration patterns are drifting from standards
    current_patterns = extract_current_patterns
    standard_patterns = get_standard_patterns

    drift_detected = current_patterns.any? do |pattern|
      !standard_patterns.include?(pattern)
    end

    {
      drift_detected: drift_detected,
      current_patterns: current_patterns,
      standard_patterns: standard_patterns
    }
  end

  def self.migration_patterns_drift_detected?
    assessment = detect_migration_drift
    assessment[:drift_detected]
  end

  def self.generate_kill_switch_report(result, output_path = nil)
    require 'fileutils'
    output_path ||= "outputs/reports/shared_result_kill_switches_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"

    # Ensure output directory exists
    FileUtils.mkdir_p(File.dirname(output_path))

    # Generate JSON report
    File.write(output_path, result.to_json)

    # Generate human-readable report
    text_output_path = output_path.sub('.json', '.txt')
    File.write(text_output_path, generate_text_summary(result))

    {
      json_report: output_path,
      text_report: text_output_path,
      result: result
    }
  end

  def self.default_scan_paths
    [
      'app/services/**/*.rb',
      'app/controllers/**/*.rb',
      'lib/**/*.rb'
    ]
  end

  def self.calculate_clarity_score_from_indicators(indicators)
    # Calculate team clarity score based on various indicators
    positive_indicators = indicators.select { |_, value| value == true }.size
    total_indicators = indicators.size
    total_indicators.positive? ? positive_indicators.to_f / total_indicators : 0.0
  end

  def self.collect_clarity_indicators
    {
      migration_documentation_updated: check_documentation_status,
      team_training_completed: check_training_status,
      code_reviews_passed: check_code_review_status,
      tests_updated: check_test_status
    }
  end

  def self.generate_recommendations(result)
    recommendations = []

    if result.emergency_stop
      recommendations << 'URGENT: Resolve critical organizational violations immediately'
      recommendations << 'Consider triggering emergency rollback procedure'
    end

    if result.critical_violations.any?
      recommendations << "Fix #{result.critical_violations.size} critical Shared::Result violations"
      recommendations << 'Ensure all new code uses ApplicationResult instead of Shared::Result'
    end

    if result.high_violations.any?
      recommendations << "Address #{result.high_violations.size} high-priority violations"
      recommendations << 'Review and update adapters if necessary'
    end

    recommendations << 'Consider team training on new patterns if violations persist'
    recommendations
  end

  def self.generate_header
    report = []
    report << ('=' * 80)
    report << 'SHARED RESULT KILL SWITCHES REPORT'
    report << ('=' * 80)
    report << ''
    report
  end

  def self.generate_summary_section(result)
    report = []
    report << 'Scan Summary:'
    report << "  Total violations: #{result.total_violations}"
    report << "  Critical: #{result.critical_violations.size}"
    report << "  High: #{result.high_violations.size}"
    report << "  Emergency stop: #{result.emergency_stop}"
    report << "  Kill switches triggered: #{result.kill_switches_triggered.size}"
    report << ''
    report
  end

  def self.generate_clean_scan_section
    report = []
    report << '✅ CLEAN SCAN - No Shared::Result violations detected'
    report << '   Ready for production deployment'
    report
  end

  def self.generate_violations_section(result)
    report = []
    report << '❌ VIOLATIONS DETECTED'
    report << ''

    if result.critical_violations.any?
      report << 'CRITICAL VIOLATIONS:'
      result.critical_violations.each do |violation|
        report << "  📍 #{violation.source_location}"
        report << "     #{violation.message}"
        report << ''
      end
    end

    if result.high_violations.any?
      report << 'HIGH PRIORITY VIOLATIONS:'
      result.high_violations.each do |violation|
        report << "  📍 #{violation.source_location}"
        report << "     #{violation.message}"
        report << ''
      end
    end

    report
  end

  def self.generate_recommendations_section(result)
    report = []
    report << 'RECOMMENDATIONS:'
    generate_recommendations(result).each do |rec|
      report << "  • #{rec}"
    end
    report
  end

  def self.generate_footer
    report = []
    report << ('=' * 80)
    report
  end

  def self.generate_text_summary(result)
    report = []
    report.concat(generate_header)
    report.concat(generate_summary_section(result))

    if result.clean_scan?
      report.concat(generate_clean_scan_section)
    else
      report.concat(generate_violations_section(result))
      report.concat(generate_recommendations_section(result))
    end

    report.concat(generate_footer)
    report.join("\n")
  end

  def self.track_migration_progress_progress
    # Placeholder method - seems to be duplicate
  end

  def self.migration_requires_complex_flags?
    # This method seems to be duplicated - keeping the one in KillSwitchMigrator
    false
  end

  # Private helper methods
  def self.count_migrated_services
    # Count services that have been migrated to ApplicationResult
    services = Dir.glob('app/services/**/*.rb')
    services.count do |service|
      File.read(service).include?('ApplicationResult')
    end
  end

  def self.count_migrated_controllers
    # Count controllers that have been migrated
    controllers = Dir.glob('app/controllers/**/*.rb')
    controllers.count { |controller| File.read(controller).include?('ApplicationResult') }
  end

  def self.count_created_adapters
    # Count adapters that have been created
    adapters = Dir.glob('app/adapters/**/*.rb')
    adapters.size
  end

  def self.count_remaining_violations
    # Count remaining Shared::Result violations
    result = KillSwitchDetector.comprehensive_scan
    result.total_violations
  end

  def self.calculate_migration_score
    # Calculate overall migration score
    progress = track_migration_progress
    total_items = progress[:services_migrated] + progress[:controllers_migrated] + progress[:adapters_created]
    total_possible = Dir.glob('app/services/**/*.rb').size + Dir.glob('app/controllers/**/*.rb').size + 1

    total_possible.positive? ? total_items.to_f / total_possible : 0.0
  end

  def self.extract_current_patterns
    # Extract current usage patterns from codebase
    patterns = []
    files = Dir.glob('app/**/*.rb')

    files.each do |file|
      content = File.read(file)
      patterns << 'ApplicationResult_usage' if content.include?('ApplicationResult')
      patterns << 'SharedResult_usage' if content.include?('Shared::Result')
    end

    patterns.uniq
  end

  def self.get_standard_patterns
    # Get standard approved patterns
    ['ApplicationResult_usage']
  end

  def self.check_documentation_status
    # Check if migration documentation is up to date
    File.exist?('docs/shared-result-migration.md')
  end

  def self.check_training_status
    # Check if team training has been completed
    # Placeholder - would check training records
    true
  end

  def self.check_code_review_status
    # Check if code reviews have been passed
    # Placeholder - would check CI/CD status
    true
  end

  def self.check_test_status
    # Check if tests have been updated
    # Placeholder - would check test coverage
    true
  end
end
