#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# COVERAGE DASHBOARD (PR15 - Phase 3)
# ==============================================================================
#
# Ce script génère un dashboard interactif de couverture de code en temps réel.
# Il lit les données SimpleCov et génère des rapports HTML avec visualisations.
#
# Usage:
#   ruby bin/templates/coverage_dashboard.rb --serve
#   ruby bin/templates/coverage_dashboard.rb --generate
#   ruby bin/templates/coverage_dashboard.rb --watch
#
# Features:
#   - Dashboard HTML interactif avec graphiques
#   - Métriques en temps réel
#   - Identification des fichiers avec faible couverture
#   - Tendances de couverture
#   - Intégration SimpleCov
#   - Mode watch pour surveillance continue
#   - Export JSON/Markdown

require 'fileutils'
require 'pathname'
require 'json'
require 'erb'
require 'webrick'
require 'uri'

# ==============================================================================
# COVERAGE DASHBOARD CLASS
# ==============================================================================

class CoverageDashboard
  COVERAGE_DIR = Pathname.new('coverage')
  REPORT_DIR = Pathname.new('public/coverage')
  DEFAULT_PORT = 3001

  def initialize(options = {})
    @options = options
    @coverage_data = nil
    @trends_data = []
    @server = nil
  end

  def run
    case @options[:mode]
    when :serve
      serve_dashboard
    when :generate
      generate_static_report
    when :watch
      watch_coverage_changes
    when :metrics
      display_metrics
    else
      show_help
    end
  end

  # ==========================================================================
  # DASHBOARD SERVER (Interactive Mode)
  # ==========================================================================

  def serve_dashboard
    puts "🚀 Starting Coverage Dashboard Server..."
    puts "📊 Dashboard will be available at: http://localhost:#{DEFAULT_PORT}"
    puts "📈 Live coverage monitoring enabled"
    puts "Press Ctrl+C to stop the server"
    puts

    # Charger les données initiales
    load_coverage_data
    start_server
  rescue Interrupt
    puts "\n🛑 Server stopped"
    stop_server
  end

  def start_server
    @server = WEBrick::HTTPServer.new(
      Port: DEFAULT_PORT,
      DocumentRoot: REPORT_DIR.to_s,
      AccessLog: [],
      Logger: WEBrick::Log.new(File::NULL)
    )

    # Routes dynamiques
    @server.mount_proc '/api/coverage' do |req, res|
      res['Content-Type'] = 'application/json'
      load_coverage_data
      res.body = JSON.pretty_generate(@coverage_data || {})
    end

    @server.mount_proc '/api/trends' do |req, res|
      res['Content-Type'] = 'application/json'
      res.body = JSON.pretty_generate(@trends_data)
    end

    @server.mount_proc '/api/refresh' do |req, res|
      res['Content-Type'] = 'application/json'
      load_coverage_data(true) # Force reload
      res.body = JSON.pretty_generate({ status: 'success', timestamp: Time.now.iso8601 })
    end

    # Page principale
    @server.mount_proc '/' do |req, res|
      res['Content-Type'] = 'text/html'
      res.body = dashboard_html
    end

    @server.start
  end

  def stop_server
    @server&.shutdown
    @server = nil
  end

  # ==========================================================================
  # STATIC REPORT GENERATION
  # ==========================================================================

  def generate_static_report
    puts "📊 Generating static coverage report..."

    # Créer les répertoires
    REPORT_DIR.mkpath
    COVERAGE_DIR.mkpath

    # Charger les données
    load_coverage_data(true)

    # Générer le rapport HTML
    html_content = dashboard_html(static: true)
    (REPORT_DIR / 'index.html').write(html_content)

    # Générer les assets CSS/JS
    generate_assets

    # Générer le rapport JSON
    generate_json_report if @coverage_data

    # Générer le rapport Markdown
    generate_markdown_report if @coverage_data

    puts "✅ Static report generated in: #{REPORT_DIR}"
    puts "📄 Open: file://#{REPORT_DIR / 'index.html'}"
  end

  def generate_assets
    # CSS Dashboard
    css_content = <<~CSS
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
      .container { max-width: 1200px; margin: 0 auto; }
      .header { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
      .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
      .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); text-align: center; }
      .metric-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
      .metric-label { color: #666; font-size: 0.9em; }
      .good { color: #28a745; }
      .warning { color: #ffc107; }
      .danger { color: #dc3545; }
      .charts { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 20px; }
      .chart-container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
      .file-list { background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); overflow: hidden; }
      .file-item { padding: 12px 16px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
      .file-item:hover { background: #f8f9fa; }
      .coverage-bar { width: 100px; height: 8px; background: #e9ecef; border-radius: 4px; overflow: hidden; }
      .coverage-fill { height: 100%; border-radius: 4px; }
      .refresh-btn { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
      .refresh-btn:hover { background: #0056b3; }
      .status-indicator { width: 12px; height: 12px; border-radius: 50%; display: inline-block; margin-right: 8px; }
      .status-good { background: #28a745; }
      .status-warning { background: #ffc107; }
      .status-danger { background: #dc3545; }
    CSS

    (REPORT_DIR / 'dashboard.css').write(css_content)

    # JavaScript Dashboard
    js_content = <<~JS
      let coverageData = null;
      let trendsData = [];

      function updateMetrics(data) {
        coverageData = data;
        document.getElementById('total-coverage').textContent = (data.metrics?.covered_percent || 0).toFixed(1) + '%';
        document.getElementById('covered-lines').textContent = data.metrics?.covered_lines || 0;
        document.getElementById('total-lines').textContent = data.metrics?.total_lines || 0;
        document.getElementById('covered-files').textContent = data.metrics?.files_covered || 0;
        document.getElementById('total-files').textContent = data.files?.length || 0;

        // Update coverage bar
        const coverageBar = document.getElementById('coverage-bar');
        const coverage = data.metrics?.covered_percent || 0;
        coverageBar.style.width = coverage + '%';
        coverageBar.className = 'coverage-fill ' + (coverage >= 90 ? 'good' : coverage >= 80 ? 'warning' : 'danger');
      }

      function updateFileList(data) {
        const container = document.getElementById('file-list');
        container.innerHTML = '';

        if (!data.files) return;

        const sortedFiles = data.files
          .sort((a, b) => (a.coverage || 0) - (b.coverage || 0))
          .slice(0, 20); // Top 20 files with lowest coverage

        sortedFiles.forEach(file => {
          const item = document.createElement('div');
          item.className = 'file-item';

          const coverage = file.coverage || 0;
          const statusClass = coverage >= 90 ? 'good' : coverage >= 80 ? 'warning' : 'danger';

          item.innerHTML = `
            <div>
              <div class="status-indicator status-${statusClass}"></div>
              <strong>${file.filename}</strong>
            </div>
            <div style="display: flex; align-items: center; gap: 10px;">
              <div class="coverage-bar">
                <div class="coverage-fill ${statusClass}" style="width: ${coverage}%"></div>
              </div>
              <span class="${statusClass}" style="font-weight: bold;">${coverage.toFixed(1)}%</span>
            </div>
          `;

          container.appendChild(item);
        });
      }

      function refreshData() {
        fetch('/api/refresh')
          .then(response => response.json())
          .then(() => loadData())
          .catch(error => console.error('Error refreshing data:', error));
      }

      function loadData() {
        fetch('/api/coverage')
          .then(response => response.json())
          .then(data => {
            updateMetrics(data);
            updateFileList(data);
          })
          .catch(error => console.error('Error loading data:', error));
      }

      function loadTrends() {
        fetch('/api/trends')
          .then(response => response.json())
          .then(data => {
            trendsData = data;
            updateTrendsChart();
          })
          .catch(error => console.error('Error loading trends:', error));
      }

      function updateTrendsChart() {
        // Simple trends chart implementation
        const canvas = document.getElementById('trends-chart');
        if (!canvas || trendsData.length === 0) return;

        const ctx = canvas.getContext('2d');
        const width = canvas.width = canvas.offsetWidth;
        const height = canvas.height = canvas.offsetHeight;

        ctx.clearRect(0, 0, width, height);

        // Draw trend line
        ctx.strokeStyle = '#007bff';
        ctx.lineWidth = 2;
        ctx.beginPath();

        trendsData.forEach((point, index) => {
          const x = (index / (trendsData.length - 1)) * (width - 40) + 20;
          const y = height - (point.coverage / 100) * (height - 40) - 20;

          if (index === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        });

        ctx.stroke();
      }

      // Auto-refresh every 30 seconds
      setInterval(() => {
        if (window.location.pathname === '/') {
          loadData();
        }
      }, 30000);

      // Initial load
      document.addEventListener('DOMContentLoaded', () => {
        loadData();
        loadTrends();

        // Setup refresh button
        document.getElementById('refresh-btn').addEventListener('click', refreshData);
      });
    JS

    (REPORT_DIR / 'dashboard.js').write(js_content)
  end

  # ==========================================================================
  # DATA LOADING AND PROCESSING
  # ==========================================================================

  def load_coverage_data(force = false)
    return if @coverage_data && !force

    coverage_file = COVERAGE_DIR / 'coverage.json'

    unless coverage_file.exist?
      @coverage_data = generate_fake_data if @options[:demo]
      return
    end

    begin
      raw_data = JSON.parse(coverage_file.read)

      @coverage_data = {
        timestamp: Time.now.iso8601,
        metrics: extract_metrics(raw_data),
        files: extract_files_data(raw_data),
        groups: extract_groups_data(raw_data),
        trends: load_trends_data
      }
    rescue JSON::ParserError => e
      puts "❌ Error parsing coverage data: #{e.message}"
      @coverage_data = nil
    end
  end

  def extract_metrics(raw_data)
    metrics = raw_data['metrics'] || {}

    {
      covered_percent: (metrics['covered_percent'] || 0).round(2),
      covered_lines: metrics['covered_lines'] || 0,
      total_lines: metrics['total_lines'] || 0,
      files_covered: metrics['files_covered'] || 0,
      missed_lines: metrics['missed_lines'] || 0
    }
  end

  def extract_files_data(raw_data)
    files = raw_data['files'] || {}

    files.map do |filepath, filedata|
      {
        filename: filepath.sub(/^app\//, ''),
        path: filepath,
        coverage: (filedata['coverage'] || 0).round(2),
        covered_lines: filedata['covered_lines'] || 0,
        missed_lines: filedata['missed_lines'] || 0,
        total_lines: (filedata['covered_lines'].to_i + filedata['missed_lines'].to_i)
      }
    end.sort_by { |f| f[:coverage] }
  end

  def extract_groups_data(raw_data)
    groups = raw_data['groups'] || {}

    groups.map do |group_name, group_data|
      {
        name: group_name,
        coverage: (group_data['coverage'] || 0).round(2),
        files_count: group_data['files']&.length || 0
      }
    end.sort_by { |g| g[:coverage] }
  end

  def load_trends_data
    trends_file = REPORT_DIR / 'trends.json'

    if trends_file.exist?
      JSON.parse(trends_file.read)
    else
      []
    end
  end

  def save_trend_data
    return unless @coverage_data

    trends_file = REPORT_DIR / 'trends.json'
    trends = load_trends_data

    # Add current data point
    trends << {
      timestamp: Time.now.iso8601,
      coverage: @coverage_data[:metrics][:covered_percent],
      total_lines: @coverage_data[:metrics][:total_lines],
      covered_lines: @coverage_data[:metrics][:covered_lines]
    }

    # Keep only last 50 data points
    trends = trends.last(50)

    trends_file.write(JSON.pretty_generate(trends))
  end

  # ==========================================================================
  # HTML GENERATION
  # ==========================================================================

  def dashboard_html(static: false)
    load_coverage_data unless @coverage_data

    ERB.new(<<~HTML).result(binding)
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Coverage Dashboard - Foresy</title>
        <link rel="stylesheet" href="dashboard.css">
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📊 Coverage Dashboard</h1>
            <p>Real-time code coverage monitoring for Foresy API</p>
            <% if static %>
              <p><strong>Static Report</strong> - Generated at <%= Time.now.strftime('%Y-%m-%d %H:%M:%S') %></p>
            <% else %>
              <p><strong>Live Server</strong> - Auto-refreshing every 30 seconds</p>
              <button id="refresh-btn" class="refresh-btn">🔄 Refresh Now</button>
            <% end %>
          </div>

          <div class="metrics">
            <div class="metric-card">
              <div class="metric-label">Total Coverage</div>
              <div id="total-coverage" class="metric-value good"><%= @coverage_data ? @coverage_data[:metrics][:covered_percent] : 0 %>%</div>
            </div>
            <div class="metric-card">
              <div class="metric-label">Covered Lines</div>
              <div id="covered-lines" class="metric-value"><%= @coverage_data ? @coverage_data[:metrics][:covered_lines] : 0 %></div>
            </div>
            <div class="metric-card">
              <div class="metric-label">Total Lines</div>
              <div id="total-lines" class="metric-value"><%= @coverage_data ? @coverage_data[:metrics][:total_lines] : 0 %></div>
            </div>
            <div class="metric-card">
              <div class="metric-label">Files Covered</div>
              <div id="covered-files" class="metric-value"><%= @coverage_data ? @coverage_data[:metrics][:files_covered] : 0 %></div>
            </div>
          </div>

          <div class="charts">
            <div class="chart-container">
              <h3>Coverage Overview</h3>
              <div style="background: #e9ecef; height: 20px; border-radius: 10px; overflow: hidden;">
                <div id="coverage-bar" class="coverage-fill good" style="width: <%= @coverage_data ? @coverage_data[:metrics][:covered_percent] : 0 %>%"></div>
              </div>
              <p style="margin-top: 10px; text-align: center;">
                <%= @coverage_data ? @coverage_data[:metrics][:covered_percent] : 0 %>% coverage
              </p>
            </div>

            <div class="chart-container">
              <h3>Coverage by Group</h3>
              <% if @coverage_data && @coverage_data[:groups].any? %>
                <% @coverage_data[:groups].each do |group| %>
                  <div style="display: flex; justify-content: space-between; margin: 5px 0;">
                    <span><%= group[:name] %></span>
                    <span class="<%= group[:coverage] >= 90 ? 'good' : group[:coverage] >= 80 ? 'warning' : 'danger' %>">
                      <%= group[:coverage] %>%
                    </span>
                  </div>
                <% end %>
              <% else %>
                <p>No group data available</p>
              <% end %>
            </div>
          </div>

          <div class="file-list">
            <div style="padding: 15px; background: #f8f9fa; border-bottom: 1px solid #dee2e6;">
              <h3 style="margin: 0;">Files Needing Attention</h3>
              <p style="margin: 5px 0 0 0; color: #666; font-size: 0.9em;">
                Showing files with lowest coverage (top 20)
              </p>
            </div>
            <div id="file-list">
              <% if @coverage_data && @coverage_data[:files].any? %>
                <% @coverage_data[:files].first(20).each do |file| %>
                  <div class="file-item">
                    <div>
                      <div class="status-indicator <%= file[:coverage] >= 90 ? 'status-good' : file[:coverage] >= 80 ? 'status-warning' : 'status-danger' %>"></div>
                      <strong><%= file[:filename] %></strong>
                    </div>
                    <div style="display: flex; align-items: center; gap: 10px;">
                      <div class="coverage-bar">
                        <div class="coverage-fill <%= file[:coverage] >= 90 ? 'good' : file[:coverage] >= 80 ? 'warning' : 'danger' %>" style="width: <%= file[:coverage] %>%"></div>
                      </div>
                      <span class="<%= file[:coverage] >= 90 ? 'good' : file[:coverage] >= 80 ? 'warning' : 'danger' %>" style="font-weight: bold;">
                        <%= file[:coverage] %>%
                      </span>
                    </div>
                  </div>
                <% end %>
              <% else %>
                <div class="file-item">
                  <p>No coverage data available. Run tests with coverage to generate data.</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <% unless static %>
          <script src="dashboard.js"></script>
        <% end %>
      </body>
      </html>
    HTML
  end

  # ==========================================================================
  # METRICS DISPLAY
  # ==========================================================================

  def display_metrics
    load_coverage_data(true)

    if @coverage_data
      puts "\n📊 COVERAGE METRICS"
      puts "=" * 50
      puts "Timestamp: #{@coverage_data[:timestamp]}"
      puts "Overall Coverage: #{@coverage_data[:metrics][:covered_percent]}%"
      puts "Covered Lines: #{@coverage_data[:metrics][:covered_lines]}"
      puts "Total Lines: #{@coverage_data[:metrics][:total_lines]}"
      puts "Files Covered: #{@coverage_data[:metrics][:files_covered]}"

      puts "\n📁 FILES WITH LOW COVERAGE (< 90%)"
      puts "-" * 40

      low_coverage_files = @coverage_data[:files].select { |f| f[:coverage] < 90 }

      if low_coverage_files.any?
        low_coverage_files.each do |file|
          puts "  #{file[:filename]}: #{file[:coverage]}% (#{file[:covered_lines]}/#{file[:total_lines]} lines)"
        end
      else
        puts "  ✅ All files have good coverage (>= 90%)"
      end

      puts "\n📈 COVERAGE BY GROUP"
      puts "-" * 30

      if @coverage_data[:groups].any?
        @coverage_data[:groups].each do |group|
          puts "  #{group[:name]}: #{group[:coverage]}% (#{group[:files_count]} files)"
        end
      else
        puts "  No group data available"
      end
    else
      puts "❌ No coverage data available"
      puts "💡 Run tests with coverage to generate data:"
      puts "   bundle exec rspec --format json --out coverage/coverage.json"
    end
  end

  # ==========================================================================
  # WATCH MODE
  # ==========================================================================

  def watch_coverage_changes
    puts "👀 Watching for coverage changes..."

    last_mtime = nil

    loop do
      coverage_file = COVERAGE_DIR / 'coverage.json'

      if coverage_file.exist?
        current_mtime = coverage_file.mtime

        if last_mtime.nil? || current_mtime > last_mtime
          puts "🔄 Coverage data updated at #{current_mtime}"
          load_coverage_data(true)
          save_trend_data
          display_metrics
          last_mtime = current_mtime
        end
      else
        puts "⏳ Waiting for coverage data..."
      end

      sleep 5
    end
  rescue Interrupt
    puts "\n🛑 Watch mode stopped"
  end

  # ==========================================================================
  # HELP AND UTILITIES
  # ==========================================================================

  def show_help
    puts <<~HELP
      Coverage Dashboard (PR15 - Phase 3)

      Usage:
        ruby bin/templates/coverage_dashboard.rb [COMMAND]

      Commands:
        serve     Start interactive dashboard server (default)
        generate  Generate static HTML report
        watch     Watch for coverage changes and display metrics
        metrics   Display current coverage metrics
        help      Show this help message

      Examples:
        ruby bin/templates/coverage_dashboard.rb --serve
        ruby bin/templates/coverage_dashboard.rb --generate
        ruby bin/templates/coverage_dashboard.rb --watch
        ruby bin/templates/coverage_dashboard.rb --metrics

      Options:
        --port=PORT     Server port (default: 3001)
        --demo         Use demo data when no coverage file exists
        --output=PATH  Output directory for static reports (default: public/coverage)

      Features:
        - Real-time coverage monitoring
        - Interactive HTML dashboard with charts
        - Identification of files with low coverage
        - Coverage trends tracking
        - Multiple output formats (HTML, JSON, Markdown)
        - Integration with SimpleCov
        - Auto-refresh and watch modes
    HELP
  end

  private

  def generate_fake_data
    {
      timestamp: Time.now.iso8601,
      metrics: {
        covered_percent: 87.5,
        covered_lines: 1247,
        total_lines: 1425,
        files_covered: 23,
        missed_lines: 178
      },
      files: [
        { filename: 'controllers/api/v1/cras_controller.rb', coverage: 65.2, covered_lines: 45, total_lines: 69 },
        { filename: 'services/cra/create_service.rb', coverage: 78.9, covered_lines: 34, total_lines: 43 },
        { filename: 'models/cra.rb', coverage: 89.1, coverage: 89.1, covered_lines: 156, total_lines: 175 },
        { filename: 'models/cra_entry.rb', coverage: 94.7, covered_lines: 89, total_lines: 94 }
      ].sort_by { |f| f[:coverage] },
      groups: [
        { name: 'Models', coverage: 91.2, files_count: 8 },
        { name: 'Controllers', coverage: 78.5, files_count: 5 },
        { name: 'Services', coverage: 85.7, files_count: 6 },
        { name: 'Jobs', coverage: 94.1, files_count: 4 }
      ]
    }
  end

  def generate_json_report
    json_file = REPORT_DIR / 'coverage.json'
    json_file.write(JSON.pretty_generate(@coverage_data))
    puts "📄 JSON report: #{json_file}"
  end

  def generate_markdown_report
    md_file = REPORT_DIR / 'coverage.md'

    content = <<~MARKDOWN
      # Coverage Report - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}

      ## Summary

      - **Overall Coverage**: #{@coverage_data[:metrics][:covered_percent]}%
      - **Covered Lines**: #{@coverage_data[:metrics][:covered_lines]}/#{@coverage_data[:metrics][:total_lines]}
      - **Files Covered**: #{@coverage_data[:metrics][:files_covered]}

      ## Coverage by Group

      MARKDOWN

    if @coverage_data[:groups].any?
      @coverage_data[:groups].each do |group|
        content += "- **#{group[:name]}**: #{group[:coverage]}% (#{group[:files_count]} files)\n"
      end
    end

    content += "\n## Files Needing Attention\n\n"

    low_coverage_files = @coverage_data[:files].select { |f| f[:coverage] < 90 }

    if low_coverage_files.any?
      low_coverage_files.each do |file|
        content += "- `#{file[:filename]}`: #{file[:coverage]}% (#{file[:covered_lines]}/#{file[:total_lines]} lines)\n"
      end
    else
      content += "✅ All files have good coverage (>= 90%)\n"
    end

    md_file.write(content)
    puts "📄 Markdown report: #{md_file}"
  end
end

# ==============================================================================
# COMMAND LINE INTERFACE
# ==============================================================================

if __FILE__ == $PROGRAM_NAME
  require 'optparse'

  options = { mode: :serve, port: DEFAULT_PORT }

  OptionParser.new do |parser|
    parser.banner = "Usage: #{$PROGRAM_NAME} [options] [command]"

    parser.on('--serve', 'Start interactive dashboard server (default)') do
      options[:mode] = :serve
    end

    parser.on('--generate', 'Generate static HTML report') do
      options[:mode] = :generate
    end

    parser.on('--watch', 'Watch for coverage changes') do
      options[:mode] = :watch
    end

    parser.on('--metrics', 'Display coverage metrics') do
      options[:mode] = :metrics
    end

    parser.on('--port=PORT', Integer, 'Server port (default: 3001)') do |port|
      options[:port] = port
    end

    parser.on('--output=PATH', 'Output directory for reports') do |path|
      options[:output] = Pathname.new(path)
    end

    parser.on('--demo', 'Use demo data when no coverage file exists') do
      options[:demo] = true
    end

    parser.on('--help', 'Show this help message') do
      puts parser
      puts
      puts "Commands:"
      puts "  serve     Start interactive dashboard (default)"
      puts "  generate  Generate static HTML report"
      puts "  watch     Watch for coverage changes"
      puts "  metrics   Display current metrics"
      puts
      puts "Examples:"
      puts "  #{$PROGRAM_NAME} --serve --port 3002"
      puts "  #{$PROGRAM_NAME} --generate --output ./reports"
      puts "  #{$PROGRAM_NAME} --metrics --demo"
      exit
    end
  end.parse!

  # Create and run dashboard
  dashboard = CoverageDashboard.new(options)
  dashboard.run
end
