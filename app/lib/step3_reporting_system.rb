# Step 3.3 Reporting System - Automatic Report Generation and Audit
# Comprehensive reporting and auditing for Domain → ApplicationResult mapping validation
# Authority: CTO/Co-CTO Validated
# Date: 2026-01-21

require 'json'
require 'csv'
require 'fileutils'
require 'date'

# rubocop:disable Metrics/ClassLength
class Step3ReportingSystem
  # Configuration
  OUTPUT_DIR = 'outputs/reports/day3'.freeze
  TEMPLATES_DIR = 'outputs/reports/day3/templates'.freeze
  ARCHIVE_DIR = 'outputs/reports/day3/archive'.freeze

  # Report types
  REPORT_TYPES = {
    leakage_detection: 'Domain Leakage Detection Report',
    contract_testing: 'Contract Testing Report',
    compliance_audit: 'Compliance Audit Report',
    error_mapping: 'Error Mapping Validation Report',
    precommit_validation: 'Pre-commit Validation Report',
    comprehensive_summary: 'Comprehensive Summary Report'
  }.freeze

  # Severity levels
  SEVERITY_LEVELS = {
    critical: { weight: 10, color: '🔴', label: 'CRITICAL' },
    high: { weight: 7, color: '🟠', label: 'HIGH' },
    medium: { weight: 4, color: '🟡', label: 'MEDIUM' },
    low: { weight: 1, color: '🔵', label: 'LOW' }
  }.freeze

  # Compliance metrics
  COMPLIANCE_METRICS = {
    domain_leakage: {
      name: 'Domain Leakage Detection',
      max_violations: 0,
      weight: 0.3,
      description: 'Domain objects and exceptions exposure'
    },
    contract_compliance: {
      name: 'Application Service Contract Compliance',
      max_violations: 0,
      weight: 0.25,
      description: 'ApplicationResult contract adherence'
    },
    error_mapping: {
      name: 'Error Mapping Standardization',
      max_violations: 0,
      weight: 0.2,
      description: 'Domain exception mapping accuracy'
    },
    service_inheritance: {
      name: 'Service Architecture Compliance',
      max_violations: 0,
      weight: 0.15,
      description: 'ApplicationService inheritance and structure'
    },
    input_validation: {
      name: 'Input Validation Coverage',
      max_violations: 0,
      weight: 0.1,
      description: 'Input validation completeness'
    }
  }.freeze

  class ReportData
    attr_reader :timestamp, :report_type, :data, :metadata

    def initialize(report_type, data = {}, metadata = {})
      @timestamp = Time.current
      @report_type = report_type
      @data = data
      @metadata = metadata
    end

    def to_h
      {
        report_info: {
          type: @report_type,
          timestamp: @timestamp.iso8601,
          version: '1.0',
          authority: 'Step 3.3 CTO/Co-CTO Validated'
        },
        data: @data,
        metadata: @metadata
      }
    end

    def to_json(*_args)
      JSON.pretty_generate(to_h)
    end
  end

  class ViolationRecord
    attr_reader :type, :file, :line, :message, :severity, :detection_method, :timestamp

    def initialize(violation_data)
      @type = violation_data[:type]
      @file = violation_data[:file]
      @line = violation_data[:line]
      @message = violation_data[:message]
      @severity = violation_data[:severity]
      @detection_method = violation_data[:detection_method] || 'DomainLeakageDetector'
      @timestamp = Time.current
    end

    def to_h
      {
        type: @type,
        file: @file,
        line: @line,
        message: @message,
        severity: @severity,
        detection_method: @detection_method,
        timestamp: @timestamp.iso8601,
        impact_score: calculate_impact_score
      }
    end

    private

    def calculate_impact_score
      SEVERITY_LEVELS[@severity.to_sym]&.dig(:weight) || 1
    end
  end

  class ComplianceAudit
    attr_reader :audit_id, :timestamp, :overall_score, :metrics, :violations

    def initialize
      @audit_id = generate_audit_id
      @timestamp = Time.current
      @metrics = {}
      @violations = []
      @overall_score = 0
    end

    def add_metric(metric_name, value, max_value = nil)
      metric_config = COMPLIANCE_METRICS[metric_name.to_sym]
      return unless metric_config

      @metrics[metric_name] = {
        value: value,
        max_value: max_value || metric_config[:max_violations],
        weight: metric_config[:weight],
        name: metric_config[:name],
        description: metric_config[:description]
      }

      calculate_overall_score
    end

    def add_violations(violations_list)
      violations_list.each do |violation|
        @violations << ViolationRecord.new(violation) if violation.is_a?(Hash)
      end
    end

    def calculate_overall_score
      total_weighted_score = 0
      total_weight = 0

      @metrics.each_value do |metric_data|
        value = metric_data[:value]
        max_value = metric_data[:max_value]
        weight = metric_data[:weight]

        # Calculate score for this metric (0-100)
        metric_score = if max_value.zero?
                         value.zero? ? 100 : 0
                       else
                         [0, 100 - ((value.to_f / max_value) * 100)].max
                       end

        total_weighted_score += metric_score * weight
        total_weight += weight
      end

      @overall_score = total_weight.positive? ? (total_weighted_score / total_weight).round(2) : 0
    end

    def compliance_level
      case @overall_score
      when 95..100 then 'EXCELLENT'
      when 85..94 then 'GOOD'
      when 70..84 then 'ACCEPTABLE'
      when 50..69 then 'NEEDS_IMPROVEMENT'
      else 'CRITICAL'
      end
    end

    def to_h
      {
        audit_info: {
          audit_id: @audit_id,
          timestamp: @timestamp.iso8601,
          overall_score: @overall_score,
          compliance_level: compliance_level,
          authority: 'Step 3.3 CTO/Co-CTO Validated'
        },
        metrics: @metrics,
        violations_summary: {
          total: @violations.size,
          by_severity: group_violations_by_severity,
          by_type: group_violations_by_type
        },
        violations: @violations.map(&:to_h)
      }
    end

    private

    def group_violations_by_severity
      @violations.group_by(&:severity).transform_values(&:size)
    end

    def group_violations_by_type
      @violations.group_by(&:type).transform_values(&:size)
    end

    def generate_audit_id
      "AUDIT_#{@timestamp.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4).upcase}"
    end
  end

  class TrendAnalyzer
    attr_reader :historical_data

    def initialize
      @historical_data = []
    end

    def add_data_point(data)
      @historical_data << {
        timestamp: Time.current,
        data: data
      }

      # Keep only last 30 data points
      @historical_data = @historical_data.last(30)
    end

    def calculate_trends
      return {} if @historical_data.size < 2

      violations_trend = calculate_violation_trend
      compliance_trend = calculate_compliance_trend
      severity_trend = calculate_severity_trend

      {
        violations_trend: violations_trend,
        compliance_trend: compliance_trend,
        severity_trend: severity_trend,
        period_analyzed: {
          start: @historical_data.first[:timestamp],
          end: @historical_data.last[:timestamp],
          data_points: @historical_data.size
        }
      }
    end

    def predict_next_scan
      return nil if @historical_data.size < 3

      violations = @historical_data.map { |d| d[:data][:total_violations] || 0 }
      trend = calculate_linear_trend(violations)

      {
        predicted_violations: [0, ((trend[:slope] * violations.size) + trend[:intercept]).round].max,
        confidence_level: calculate_confidence_level(violations),
        trend_direction: if trend[:slope].positive?
                           'INCREASING'
                         else
                           trend[:slope].negative? ? 'DECREASING' : 'STABLE'
                         end
      }
    end

    private

    def calculate_violation_trend
      violations = @historical_data.map { |d| d[:data][:total_violations] || 0 }
      return { direction: 'UNKNOWN', change_percentage: 0 } if violations.size < 2

      recent_avg = violations.last(3).sum / 3.0
      older_avg = violations.first(3).sum / 3.0

      change_percentage = older_avg.positive? ? ((recent_avg - older_avg) / older_avg * 100).round(1) : 0

      {
        direction: if change_percentage > 5
                     'INCREASING'
                   else
                     change_percentage < -5 ? 'DECREASING' : 'STABLE'
                   end,
        change_percentage: change_percentage
      }
    end

    def calculate_compliance_trend
      scores = @historical_data.map { |d| d[:data][:compliance_score] || 0 }
      return { direction: 'UNKNOWN', change_percentage: 0 } if scores.size < 2

      recent_avg = scores.last(3).sum / 3.0
      older_avg = scores.first(3).sum / 3.0

      change_percentage = older_avg.positive? ? ((recent_avg - older_avg) / older_avg * 100).round(1) : 0

      {
        direction: if change_percentage > 1
                     'IMPROVING'
                   else
                     change_percentage < -1 ? 'DECLINING' : 'STABLE'
                   end,
        change_percentage: change_percentage
      }
    end

    def calculate_severity_trend
      critical_counts = @historical_data.map { |d| d[:data][:critical_violations] || 0 }
      return { direction: 'UNKNOWN', change_percentage: 0 } if critical_counts.size < 2

      recent_avg = critical_counts.last(3).sum / 3.0
      older_avg = critical_counts.first(3).sum / 3.0

      change_percentage = older_avg.positive? ? ((recent_avg - older_avg) / older_avg * 100).round(1) : 0

      {
        direction: if change_percentage.positive?
                     'INCREASING'
                   else
                     change_percentage.negative? ? 'DECREASING' : 'STABLE'
                   end,
        change_percentage: change_percentage
      }
    end

    def calculate_linear_trend(values)
      n = values.size
      x_sum = (0...n).sum
      y_sum = values.sum
      xy_sum = (0...n).sum { |i| i * values[i] }
      x2_sum = (0...n).sum { |i| i * i }

      slope = ((n * xy_sum) - (x_sum * y_sum)) / ((n * x2_sum) - (x_sum * x_sum))
      intercept = (y_sum - (slope * x_sum)) / n

      { slope: slope, intercept: intercept }
    end

    def calculate_confidence_level(values)
      variance = values.sum { |v| (v - (values.sum / values.size))**2 } / values.size
      standard_deviation = Math.sqrt(variance)
      mean = values.sum / values.size

      # Confidence based on consistency (lower standard deviation = higher confidence)
      coefficient_of_variation = mean.positive? ? standard_deviation / mean : 1

      if coefficient_of_variation < 0.1 then 'HIGH'
      elsif coefficient_of_variation < 0.3 then 'MEDIUM'
      else 'LOW'
      end
    end
  end

  # Main reporting methods
  def self.generate_leakage_report(scan_result)
    report_data = ReportData.new('domain_leakage_detection', scan_result.to_h)

    output_path = generate_output_path('leakage_detection')

    ensure_directories

    # Generate JSON report
    File.write(output_path[:json], report_data.to_json)

    # Generate human-readable report
    File.write(output_path[:txt], generate_text_report(report_data))

    # Generate CSV summary
    File.write(output_path[:csv], generate_csv_report(report_data))

    # Generate HTML report
    File.write(output_path[:html], generate_html_report(report_data))

    {
      json: output_path[:json],
      txt: output_path[:txt],
      csv: output_path[:csv],
      html: output_path[:html],
      report_data: report_data
    }
  end

  def self.generate_compliance_audit(audit_data)
    audit = ComplianceAudit.new

    # Add metrics
    audit_data.each do |metric_name, value|
      audit.add_metric(metric_name, value)
    end

    # Add violations
    audit.add_violations(audit_data[:violations]) if audit_data[:violations]

    report_data = ReportData.new('compliance_audit', audit.to_h)

    output_path = generate_output_path('compliance_audit')

    ensure_directories

    # Generate reports in multiple formats
    File.write(output_path[:json], report_data.to_json)
    File.write(output_path[:txt], generate_audit_text_report(report_data))
    File.write(output_path[:html], generate_audit_html_report(report_data))

    {
      json: output_path[:json],
      txt: output_path[:txt],
      html: output_path[:html],
      audit: audit,
      report_data: report_data
    }
  end

  def self.generate_comprehensive_summary(reports_data)
    summary = {
      generated_at: Time.current.iso8601,
      authority: 'Step 3.3 CTO/Co-CTO Validated',
      reports_analyzed: reports_data.size,
      overall_status: determine_overall_status(reports_data),
      key_metrics: extract_key_metrics(reports_data),
      violations_summary: summarize_violations(reports_data),
      compliance_score: calculate_overall_compliance_score(reports_data),
      recommendations: generate_recommendations(reports_data)
    }

    report_data = ReportData.new('comprehensive_summary', summary)

    output_path = generate_output_path('comprehensive_summary')

    ensure_directories

    File.write(output_path[:json], report_data.to_json)
    File.write(output_path[:txt], generate_summary_text_report(report_data))

    {
      json: output_path[:json],
      txt: output_path[:txt],
      summary: summary,
      report_data: report_data
    }
  end

  def self.archive_report(report_path)
    return unless File.exist?(report_path)

    archive_filename = "#{File.basename(report_path,
                                        '.*')}_#{Time.current.strftime('%Y%m%d_%H%M%S')}#{File.extname(report_path)}"
    archive_path = File.join(ARCHIVE_DIR, archive_filename)

    FileUtils.mv(report_path, archive_path)
    archive_path
  end

  def self.cleanup_old_reports(keep_days = 30)
    return unless Dir.exist?(OUTPUT_DIR)

    cutoff_date = Date.today - keep_days

    Dir.glob(File.join(OUTPUT_DIR, '*.json')).each do |file|
      file_date = Date.strptime(File.basename(file)[/\d{8}/], '%Y%m%d')
      archive_report(file) if file_date < cutoff_date
    end
  end

  def self.generate_dashboard_data
    recent_reports = load_recent_reports(7) # Last 7 days

    {
      total_reports: recent_reports.size,
      compliance_trend: calculate_compliance_trend(recent_reports),
      violation_trends: calculate_violation_trends(recent_reports),
      most_common_violations: find_most_common_violations(recent_reports),
      service_compliance: analyze_service_compliance(recent_reports),
      last_scan: recent_reports.max_by { |r| r[:timestamp] }
    }
  end

  def self.generate_output_path(report_type)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')

    {
      json: File.join(OUTPUT_DIR, "#{report_type}_#{timestamp}.json"),
      txt: File.join(OUTPUT_DIR, "#{report_type}_#{timestamp}.txt"),
      csv: File.join(OUTPUT_DIR, "#{report_type}_#{timestamp}.csv"),
      html: File.join(OUTPUT_DIR, "#{report_type}_#{timestamp}.html")
    }
  end

  def self.ensure_directories
    [OUTPUT_DIR, TEMPLATES_DIR, ARCHIVE_DIR].each do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  def self.generate_text_report(report_data)
    [
      text_report_header(report_data),
      text_report_body(report_data),
      text_report_footer(report_data)
    ].compact.join("\n")
  end

  private_class_method :text_report_header, :text_report_body, :text_report_footer,
                       :generate_csv_report, :generate_html_report, :html_report_header,
                       :html_report_body, :html_report_footer, :generate_audit_text_report,
                       :generate_summary_section, :generate_violations_section,
                       :generate_violations_list, :generate_violation_item, :generate_clean_scan_message

  def self.text_report_header(report_data)
    report_lines = []

    report_lines << ('=' * 80)
    report_lines << 'DOMAIN LEAKAGE DETECTION REPORT'
    report_lines << ('=' * 80)
    report_lines << ''
    report_lines << "Report Generated: #{report_data.timestamp}"
    report_lines << "Authority: #{report_data.metadata[:authority] || 'Step 3.3 Validated'}"
    report_lines << ''

    report_lines.join("\n")
  end

  def self.text_report_body(report_data)
    data = report_data.data
    report_lines = []

    # Summary
    if data[:summary]
      summary = data[:summary]
      report_lines << 'SCAN SUMMARY:'
      report_lines << "  Files scanned: #{summary[:files_scanned]}"
      report_lines << "  Scan time: #{summary[:scan_time]} seconds"
      report_lines << "  Total violations: #{summary[:total]}"
      report_lines << "  Critical: #{summary[:critical]}"
      report_lines << "  High: #{summary[:high]}"
      report_lines << "  Medium: #{summary[:medium]}"
      report_lines << ''
    end

    # Violations details
    if data[:violations]&.any?
      report_lines << 'VIOLATIONS DETECTED:'
      report_lines << ''

      data[:violations].each_with_index do |violation, index|
        severity_config = SEVERITY_LEVELS[violation[:severity].to_sym]
        report_lines << "#{index + 1}. #{severity_config[:color]} " \
                        "#{violation[:type].to_s.upcase} (#{violation[:severity].upcase})"
        report_lines << "   File: #{violation[:file]}:#{violation[:line]}"
        report_lines << "   Message: #{violation[:message]}"
        report_lines << "   Impact Score: #{violation[:impact_score] || 'N/A'}"
        report_lines << ''
      end
    else
      report_lines << '✅ CLEAN SCAN - No violations detected'
      report_lines << '   Domain → ApplicationResult mapping is compliant'
    end

    report_lines.join("\n")
  end

  def self.text_report_footer(_report_data)
    ('=' * 80)
  end

  def self.generate_csv_report(report_data)
    CSV.generate do |csv|
      # Header
      csv << ['Type', 'File', 'Line', 'Severity', 'Message', 'Impact Score', 'Timestamp']

      # Data
      report_data.data[:violations]&.each do |violation|
        csv << [
          violation[:type],
          violation[:file],
          violation[:line],
          violation[:severity],
          violation[:message],
          violation[:impact_score] || 'N/A',
          report_data.timestamp
        ]
      end
    end
  end

  def self.generate_html_report(report_data)
    [
      html_report_header(report_data),
      html_report_body(report_data),
      html_report_footer(report_data)
    ].join
  end

  def self.html_report_header(report_data)
    html = []
    html << '<!DOCTYPE html>'
    html << '<html>'
    html << '<head>'
    html << '  <title>Domain Leakage Detection Report</title>'
    html << "  <meta charset='utf-8'>"
    html << '  <style>'
    html << '    body { font-family: Arial, sans-serif; margin: 40px; }'
    html << '    .header { background-color: #f8f9fa; padding: 20px; border-radius: 8px; }'
    html << '    .violation { border-left: 4px solid; padding: 15px; margin: 10px 0; }'
    html << '    .critical { border-color: #dc3545; background-color: #f8d7da; }'
    html << '    .high { border-color: #fd7e14; background-color: #fff3cd; }'
    html << '    .medium { border-color: #ffc107; background-color: #fff3cd; }'
    html << '    .summary { background-color: #e9ecef; padding: 15px; margin: 20px 0; border-radius: 8px; }'
    html << '  </style>'
    html << '</head>'
    html << '<body>'

    # Header
    html << "<div class='header'>"
    html << '  <h1>🔍 Domain Leakage Detection Report</h1>'
    html << "  <p><strong>Generated:</strong> #{report_data.timestamp}</p>"
    html << '  <p><strong>Authority:</strong> Step 3.3 CTO/Co-CTO Validated</p>'
    html << '</div>'

    html.join
  end

  def self.html_report_body(report_data)
    data = report_data.data
    html = []

    html << generate_summary_section(data[:summary]) if data[:summary]
    html << generate_violations_section(data[:violations])

    html.compact.join
  end

  def self.generate_summary_section(summary)
    return nil unless summary

    html = []
    html << "<div class='summary'>"
    html << '  <h2>📊 Scan Summary</h2>'
    html << '  <ul>'
    html << "    <li><strong>Files scanned:</strong> #{summary[:files_scanned]}</li>"
    html << "    <li><strong>Scan time:</strong> #{summary[:scan_time]} seconds</li>"
    html << "    <li><strong>Total violations:</strong> #{summary[:total]}</li>"
    html << "    <li><strong>Critical:</strong> #{summary[:critical]}</li>"
    html << "    <li><strong>High:</strong> #{summary[:high]}</li>"
    html << "    <li><strong>Medium:</strong> #{summary[:medium]}</li>"
    html << '  </ul>'
    html << '</div>'
    html
  end

  def self.generate_violations_section(violations)
    if violations&.any?
      generate_violations_list(violations)
    else
      generate_clean_scan_message
    end
  end

  def self.generate_violations_list(violations)
    html = ['<h2>🚨 Violations Detected</h2>']

    violations.each do |violation|
      html << generate_violation_item(violation)
    end

    html
  end

  def self.generate_violation_item(violation)
    severity_class = violation[:severity]
    severity_config = SEVERITY_LEVELS[severity_class.to_sym]

    [
      "<div class='violation #{severity_class}'>",
      "  <h3>#{severity_config[:color]} #{violation[:type].to_s.upcase}</h3>",
      "  <p><strong>File:</strong> #{violation[:file]}:#{violation[:line]}</p>",
      "  <p><strong>Severity:</strong> #{violation[:severity].upcase}</p>",
      "  <p><strong>Message:</strong> #{violation[:message]}</p>",
      "  <p><strong>Impact Score:</strong> #{violation[:impact_score] || 'N/A'}</p>",
      '</div>'
    ]
  end

  def self.generate_clean_scan_message
    [
      "<div class='summary'>",
      '  <h2>✅ Clean Scan</h2>',
      '  <p>No violations detected. Domain → ApplicationResult mapping is compliant.</p>',
      '</div>'
    ]
  end

  def self.html_report_footer(_report_data)
    '</body></html>'
  end

  def self.generate_audit_text_report(report_data)
    audit_sections(report_data).join("\n")
  end

  private_class_method :audit_sections, :audit_header, :audit_entries, :audit_summary,
                       :generate_summary_text_report, :determine_overall_status,
                       :extract_key_metrics, :summarize_violations,
                       :calculate_overall_compliance_score, :generate_recommendations,
                       :load_recent_reports, :calculate_compliance_from_report,
                       :calculate_compliance_trend, :calculate_violation_trends,
                       :calculate_violation_trend, :find_most_common_violations,
                       :analyze_service_compliance

  def self.audit_sections(report_data)
    [
      audit_header(report_data),
      audit_entries(report_data),
      audit_summary(report_data)
    ]
  end

  def self.audit_header(report_data)
    audit_info = report_data.data[:audit_info]

    lines = []
    lines << ('=' * 80)
    lines << 'COMPLIANCE AUDIT REPORT'
    lines << ('=' * 80)
    lines << ''
    lines << "Audit ID: #{audit_info[:audit_id]}"
    lines << "Generated: #{audit_info[:timestamp]}"
    lines << "Overall Score: #{audit_info[:overall_score]}/100"
    lines << "Compliance Level: #{audit_info[:compliance_level]}"
    lines << ''

    lines.join("\n")
  end

  def self.audit_entries(report_data)
    audit_data = report_data.data

    lines = []

    # Metrics
    lines << 'METRICS:'
    lines << ('-' * 40)
    audit_data[:metrics].each_value do |metric_data|
      lines << "#{metric_data[:name]}: #{metric_data[:value]}/#{metric_data[:max_value]} " \
               "(weight: #{metric_data[:weight]})"
      lines << "  Description: #{metric_data[:description]}"
      lines << ''
    end

    lines.join("\n")
  end

  def self.audit_summary(report_data)
    audit_data = report_data.data
    violations_summary = audit_data[:violations_summary]

    lines = []

    lines << 'VIOLATIONS SUMMARY:'
    lines << ('-' * 40)
    lines << "Total violations: #{violations_summary[:total]}"

    if violations_summary[:by_severity].any?
      lines << 'By severity:'
      violations_summary[:by_severity].each do |severity, count|
        severity_config = SEVERITY_LEVELS[severity.to_sym]
        lines << "  #{severity_config[:color]} #{severity.upcase}: #{count}"
      end
    end

    if violations_summary[:by_type].any?
      lines << 'By type:'
      violations_summary[:by_type].each do |type, count|
        lines << "  - #{type}: #{count}"
      end
    end

    lines << ''
    lines << ('=' * 80)

    lines.join("\n")
  end

  def self.generate_summary_text_report(report_data)
    summary = report_data.data

    lines = []
    lines << ('=' * 80)
    lines << 'COMPREHENSIVE SUMMARY REPORT'
    lines << ('=' * 80)
    lines << ''
    lines << "Generated: #{summary[:generated_at]}"
    lines << "Authority: #{summary[:authority]}"
    lines << "Reports Analyzed: #{summary[:reports_analyzed]}"
    lines << "Overall Status: #{summary[:overall_status]}"
    lines << "Compliance Score: #{summary[:compliance_score]}/100"
    lines << ''

    # Key metrics
    lines << 'KEY METRICS:'
    lines << ('-' * 40)
    summary[:key_metrics].each do |metric, value|
      lines << "#{metric}: #{value}"
    end
    lines << ''

    # Recommendations
    if summary[:recommendations].any?
      lines << 'RECOMMENDATIONS:'
      lines << ('-' * 40)
      summary[:recommendations].each_with_index do |rec, index|
        lines << "#{index + 1}. #{rec}"
      end
      lines << ''
    end

    lines << ('=' * 80)

    lines.join("\n")
  end

  # Helper methods for comprehensive analysis
  def self.determine_overall_status(reports_data)
    all_clean = reports_data.all? { |r| r[:clean_scan] }
    any_critical = reports_data.any? { |r| r[:critical_violations].to_i.positive? }

    if all_clean then 'COMPLIANT'
    elsif any_critical then 'CRITICAL_VIOLATIONS'
    else 'VIOLATIONS_DETECTED'
    end
  end

  def self.extract_key_metrics(reports_data)
    total_violations = reports_data.sum { |r| r[:total_violations].to_i }
    total_critical = reports_data.sum { |r| r[:critical_violations].to_i }
    total_files = reports_data.sum { |r| r[:files_scanned].to_i }
    avg_compliance = reports_data.sum { |r| r[:compliance_score].to_i } / reports_data.size.to_f

    {
      total_violations: total_violations,
      total_critical_violations: total_critical,
      total_files_scanned: total_files,
      average_compliance_score: avg_compliance.round(2),
      reports_with_violations: reports_data.count { |r| r[:total_violations].to_i.positive? }
    }
  end

  def self.summarize_violations(reports_data)
    all_violations = reports_data.flat_map { |r| r[:violations] || [] }

    {
      total: all_violations.size,
      by_severity: all_violations.group_by { |v| v[:severity] }.transform_values(&:size),
      by_type: all_violations.group_by { |v| v[:type] }.transform_values(&:size),
      most_common_file: all_violations.group_by { |v| v[:file] }.max_by { |_, v| v.size }&.first
    }
  end

  def self.calculate_overall_compliance_score(reports_data)
    return 100 if reports_data.empty?

    total_score = reports_data.sum { |r| r[:compliance_score].to_i }
    (total_score / reports_data.size).round(2)
  end

  def self.generate_recommendations(reports_data)
    recommendations = []

    # Analyze patterns and suggest improvements
    all_violations = reports_data.flat_map { |r| r[:violations] || [] }

    if all_violations.any?
      # Check for most common violation type
      violation_types = all_violations.group_by { |v| v[:type] }.sort_by { |_, v| -v.size }
      most_common = violation_types.first

      if most_common
        recommendations << "Focus on resolving #{most_common[0]} violations (#{most_common[1].size} occurrences)"
      end

      # Check for critical violations
      critical_violations = all_violations.select { |v| v[:severity] == 'critical' }
      if critical_violations.any?
        recommendations << "Address #{critical_violations.size} critical violations immediately"
      end
    else
      recommendations << 'Maintain current high compliance standards'
      recommendations << 'Continue regular monitoring and validation'
    end

    # General recommendations
    recommendations << 'Ensure all team members are trained on Step 3.3 patterns'
    recommendations << 'Regular review of Domain → ApplicationResult mapping compliance'

    recommendations
  end

  def self.load_recent_reports(days = 7)
    return [] unless Dir.exist?(OUTPUT_DIR)

    cutoff_date = Date.today - days
    report_files = Dir.glob(File.join(OUTPUT_DIR, 'leakage_detection_*.json'))

    recent_reports = []

    report_files.each do |file|
      file_date_str = File.basename(file)[/\d{8}_\d{6}/]
      file_date = Date.strptime(file_date_str[0..7], '%Y%m%d')

      if file_date >= cutoff_date
        report_data = JSON.parse(File.read(file))
        recent_reports << {
          timestamp: file_date,
          total_violations: report_data.dig('summary', 'total') || 0,
          critical_violations: report_data.dig('summary', 'critical') || 0,
          compliance_score: calculate_compliance_from_report(report_data),
          clean_scan: (report_data.dig('summary', 'total') || 0).zero?,
          violations: report_data['violations'] || []
        }
      end
    rescue StandardError
      # Skip files that can't be parsed
      next
    end

    recent_reports.sort_by { |r| r[:timestamp] }
  end

  def self.calculate_compliance_from_report(report_data)
    total = report_data.dig('summary', 'total') || 0
    critical = report_data.dig('summary', 'critical') || 0
    high = report_data.dig('summary', 'high') || 0

    # Simple compliance calculation
    score = 100 - ((critical * 10) + (high * 5) + (total * 1))
    [0, score].max
  end

  def self.calculate_compliance_trend(reports_data)
    return { direction: 'UNKNOWN', change_percentage: 0 } if reports_data.size < 2

    recent_avg = reports_data.last(3).sum { |r| r[:compliance_score] } / 3.0
    older_avg = reports_data.first(3).sum { |r| r[:compliance_score] } / 3.0

    change_percentage = older_avg.positive? ? ((recent_avg - older_avg) / older_avg * 100).round(1) : 0

    {
      direction: if change_percentage > 1
                   'IMPROVING'
                 else
                   change_percentage < -1 ? 'DECLINING' : 'STABLE'
                 end,
      change_percentage: change_percentage
    }
  end

  def self.calculate_violation_trends(reports_data)
    {
      total: calculate_violation_trend(reports_data.map { |r| r[:total_violations] }),
      critical: calculate_violation_trend(reports_data.map { |r| r[:critical_violations] })
    }
  end

  def self.calculate_violation_trend(values)
    return { direction: 'UNKNOWN', change_percentage: 0 } if values.size < 2

    recent_avg = values.last(3).sum / 3.0
    older_avg = values.first(3).sum / 3.0

    change_percentage = older_avg.positive? ? ((recent_avg - older_avg) / older_avg * 100).round(1) : 0

    {
      direction: if change_percentage > 5
                   'INCREASING'
                 else
                   change_percentage < -5 ? 'DECREASING' : 'STABLE'
                 end,
      change_percentage: change_percentage
    }
  end

  def self.find_most_common_violations(reports_data)
    all_violations = reports_data.flat_map { |r| r[:violations] || [] }
    violations_by_type = all_violations.group_by { |v| v[:type] }
    sorted_violations = violations_by_type.sort_by { |_, v| -v.size }
    top_five_types = sorted_violations.first(5)

    top_five_types.map do |type, violations|
      { type: type, count: violations.size }
    end
  end

  def self.analyze_service_compliance(reports_data)
    # This would analyze compliance per service if we had service-level data
    {
      overall_compliance: calculate_overall_compliance_score(reports_data),
      trend: calculate_compliance_trend(reports_data)
    }
  end
end

# CLI interface for reporting system
if __FILE__ == $PROGRAM_NAME
  require 'optparse'

  options = {
    report_type: 'leakage_detection',
    output_format: 'all',
    days: 7,
    archive: false,
    dashboard: false
  }

  OptionParser.new do |parser|
    parser.banner = 'Usage: ruby step3_reporting_system.rb [options]'

    parser.on('--type TYPE', '--report-type TYPE',
              'Report type (leakage_detection, compliance_audit, comprehensive_summary)') do |type|
      options[:report_type] = type
    end

    parser.on('--format FORMAT', '--output-format FORMAT', 'Output format (json, txt, csv, html, all)') do |format|
      options[:output_format] = format
    end

    parser.on('--days DAYS', 'Number of days for historical analysis') do |days|
      options[:days] = days.to_i
    end

    parser.on('--archive', 'Archive old reports') do
      options[:archive] = true
    end

    parser.on('--dashboard', 'Generate dashboard data') do
      options[:dashboard] = true
    end

    parser.on('--help', 'Show this help') do
      puts parser
      puts ''
      puts 'Examples:'
      puts '  ruby step3_reporting_system.rb --type leakage_detection --format all'
      puts '  ruby step3_reporting_system.rb --dashboard --days 30'
      puts '  ruby step3_reporting_system.rb --archive'
      exit 0
    end
  end.parse!

  # Execute reporting system
  if options[:dashboard]
    dashboard_data = Step3ReportingSystem.generate_dashboard_data
    puts 'Dashboard Data:'
    puts JSON.pretty_generate(dashboard_data)
  end

  if options[:archive]
    Step3ReportingSystem.cleanup_old_reports
    puts 'Old reports archived successfully'
  end

  # Generate report based on type
  case options[:report_type]
  when 'leakage_detection'
    # This would typically be called with actual scan results
    puts 'Leakage detection report generation requires scan results'
  when 'compliance_audit'
    puts 'Compliance audit report generation requires audit data'
  when 'comprehensive_summary'
    puts 'Comprehensive summary report generation requires multiple reports data'
  end
end

class Step3ReportingSystem
  class TextReportBuilder
    def initialize(context)
      @context = context
    end
    # rubocop:enable Metrics/ClassLength

    def call
      @context.generate_text_report
    end
  end

  class HtmlReportBuilder
    def initialize(context)
      @context = context
    end

    def call
      @context.generate_html_report
    end
  end
end
