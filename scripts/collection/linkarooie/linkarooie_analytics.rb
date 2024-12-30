#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'
require 'fileutils'
require 'time'
require 'optparse'

class LinkarooieAnalytics
  def initialize(username, options = {})
    @username = username
    @base_url = "https://linkarooie.com/#{username}/analytics"
    @report_dir = options[:output_dir] || "reports/analytics"
    @output_format = options[:format] || 'stdout'
    FileUtils.mkdir_p(@report_dir) if @output_format != 'stdout'
  end

  def fetch_data
    response = HTTParty.get(@base_url, headers: {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    })
    
    raise "Failed to fetch analytics (Status: #{response.code})" unless response.code == 200
    
    @doc = Nokogiri::HTML(response.body)
    extract_data
  end

  private

  def extract_data
    {
      timestamp: Time.now.iso8601,
      overall_metrics: extract_overall_metrics,
      latest_daily_metrics: extract_latest_daily_metrics,
      daily_views: extract_chart_data('chart-1'),
      unique_visitors: extract_chart_data('chart-2'),
      top_locations: extract_locations,
      link_analytics: extract_link_analytics,
      achievement_analytics: extract_achievement_analytics,
      browser_usage: extract_browser_usage
    }
  end

  def extract_overall_metrics
    metrics = {}
    @doc.css('.grid-cols-2.sm\\:grid-cols-4 .bg-gray-800').each do |metric|
      title = metric.at_css('h2')&.text&.strip
      value = metric.at_css('p')&.text&.strip&.gsub(',', '')&.to_i
      metrics[sanitize_key(title)] = value if title && value
    end
    metrics
  end

  def extract_latest_daily_metrics
    date_text = @doc.at_css('h2:contains("Latest Daily Metrics")')&.text
    date = date_text.match(/\((.*?)\)/)[1] rescue Time.now.strftime("%B %d, %Y")
    
    metrics = {}
    @doc.css('.grid-cols-2.sm\\:grid-cols-4 .text-center').each do |metric|
      title = metric.at_css('h3')&.text&.strip
      value = metric.at_css('p')&.text&.strip&.to_i
      metrics[sanitize_key(title)] = value if title && value
    end
    
    {
      date: date,
      metrics: metrics
    }
  end

  def extract_chart_data(chart_id)
    script = @doc.at_css("script:contains('#{chart_id}')")&.text
    return [] unless script

    data_match = script.match(/\[\[(.*?)\]\]/)
    return [] unless data_match

    data_string = data_match[1]
    data_points = data_string.scan(/"([\d-]+)",(\d+)/)
    
    data_points.map do |date, value|
      {
        date: date,
        value: value.to_i
      }
    end
  end

  def extract_locations
    locations = []
    @doc.css('h2:contains("Top Visitor Locations") + div table tbody tr').each do |row|
      country = row.at_css('td:first-child')&.text&.strip
      views = row.at_css('td:last-child')&.text&.strip&.gsub(',', '')&.to_i
      locations << { country: country, views: views } if country && views
    end
    locations
  end

  def extract_link_analytics
    links = []
    @doc.css('h2:contains("Link Analytics") + p + div table tbody tr').each do |row|
      title = row.at_css('th')&.text&.strip
      total_clicks = row.css('td')[0]&.text&.strip&.to_i
      unique_visitors = row.css('td')[1]&.text&.strip&.to_i
      links << {
        title: title,
        total_clicks: total_clicks,
        unique_visitors: unique_visitors
      } if title && total_clicks && unique_visitors
    end
    links
  end

  def extract_achievement_analytics
    achievements = []
    @doc.css('h2:contains("Achievement Analytics") + p + div table tbody tr').each do |row|
      title = row.at_css('th')&.text&.strip
      total_views = row.css('td')[0]&.text&.strip&.to_i
      unique_viewers = row.css('td')[1]&.text&.strip&.to_i
      achievements << {
        title: title,
        total_views: total_views,
        unique_viewers: unique_viewers
      } if title && total_views && unique_viewers
    end
    achievements
  end

  def extract_browser_usage
    script = @doc.at_css("script:contains('chart-3')")&.text
    return [] unless script

    data_match = script.match(/\[\[(.*?)\]\]/)
    return [] unless data_match

    data_string = data_match[1]
    browsers = data_string.scan(/"([^"]+)",(\d+)/)
    
    browsers.map do |browser, percentage|
      {
        browser: browser,
        percentage: percentage.to_i
      }
    end
  end

  def sanitize_key(text)
    return nil unless text
    text.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
  end

  public

  def generate_report
    data = fetch_data
    
    case @output_format
    when 'json'
      output_json(data)
    when 'markdown'
      output_markdown(data)
    else
      output_stdout(data)
    end
  end

  private

  def output_json(data)
    json_file = File.join(@report_dir, "#{Time.now.strftime('%Y%m%d')}_#{@username}_analytics.json")
    File.write(json_file, JSON.pretty_generate(data))
    { json_path: json_file, data: data }
  end
  
  def output_markdown(data)
    markdown = generate_markdown_report(data)
    md_file = File.join(@report_dir, "#{Time.now.strftime('%Y%m%d')}_#{@username}_analytics.md")
    File.write(md_file, markdown)
    { markdown_path: md_file, data: data }
  end

  def output_stdout(data)
    puts generate_markdown_report(data)
    { data: data }
  end

  def generate_markdown_report(data)
    <<~MARKDOWN
      # Linkarooie Analytics Report for @#{@username}

      Generated on: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}

      ## Overall Metrics

      #{format_overall_metrics(data[:overall_metrics])}

      ## Latest Daily Metrics (#{data[:latest_daily_metrics][:date]})

      #{format_daily_metrics(data[:latest_daily_metrics][:metrics])}

      ## Top Visitor Locations

      #{format_locations(data[:top_locations])}

      ## Link Performance

      #{format_link_analytics(data[:link_analytics])}

      ## Achievement Performance

      #{format_achievement_analytics(data[:achievement_analytics])}

      ## Browser Usage

      #{format_browser_usage(data[:browser_usage])}

      ## Historical Data

      - Daily views and unique visitors data available in the JSON report
      #{@output_format != 'stdout' ? "- Full data exported to: #{@report_dir}" : ''}
    MARKDOWN
  end

  def format_overall_metrics(metrics)
    metrics.map { |key, value| "- #{key.gsub('_', ' ').capitalize}: #{value.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,')}" }.join("\n")
  end

  def format_daily_metrics(metrics)
    metrics.map { |key, value| "- #{key.gsub('_', ' ').capitalize}: #{value.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,')}" }.join("\n")
  end

  def format_locations(locations)
    locations.map { |loc| "- #{loc[:country]}: #{loc[:views].to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,')} views" }.join("\n")
  end

  def format_link_analytics(links)
    links.map do |link|
      "### #{link[:title]}\n\n" \
      "- Total Clicks: #{link[:total_clicks]}\n" \
      "- Unique Visitors: #{link[:unique_visitors]}"
    end.join("\n\n")
  end

  def format_achievement_analytics(achievements)
    achievements.map do |achievement|
      "### #{achievement[:title]}\n\n" \
      "- Total Views: #{achievement[:total_views]}\n" \
      "- Unique Viewers: #{achievement[:unique_viewers]}"
    end.join("\n\n")
  end

  def format_browser_usage(browsers)
    browsers.map { |b| "- #{b[:browser]}: #{b[:percentage]}%" }.join("\n")
  end
end

if __FILE__ == $0
  def print_usage
    puts <<~USAGE
      Linkarooie Analytics Scraper

      Usage: #{File.basename($0)} [options]

      Options:
          -u, --username USERNAME    Linkarooie username (default: loftwah)
          -f, --format FORMAT        Output format: stdout, markdown, json (default: stdout)
          -o, --output-dir DIR       Output directory (default: reports/analytics)
          -h, --help                Show this help message

      Examples:
          # Default usage (stdout output for loftwah)
          #{File.basename($0)}

          # Specify a different user
          #{File.basename($0)} -u another_user

          # Generate markdown file
          #{File.basename($0)} -f markdown

          # Generate JSON file with custom output directory
          #{File.basename($0)} -f json -o /custom/path

      Note: When using markdown or json formats, files are saved in the output directory
            with names like YYYYMMDD_analytics.md or YYYYMMDD_analytics.json
    USAGE
  end

  options = {
    username: 'loftwah',
    format: 'stdout',
    output_dir: 'reports/analytics'
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"

    opts.on("-u", "--username USERNAME", "Linkarooie username (default: #{options[:username]})") do |u|
      options[:username] = u
    end

    opts.on("-f", "--format FORMAT", %w[stdout markdown json], 
            "Output format: stdout, markdown, json (default: #{options[:format]})") do |f|
      options[:format] = f
    end

    opts.on("-o", "--output-dir DIR", "Output directory (default: #{options[:output_dir]})") do |d|
      options[:output_dir] = d
    end

    opts.on("-h", "--help", "Show this help message") do
      print_usage
      exit
    end
  end

  begin
    parser.parse!

    analytics = LinkarooieAnalytics.new(options[:username], options)
    result = analytics.generate_report

    case options[:format]
    when 'json'
      puts "JSON report generated: #{result[:json_path]}"
    when 'markdown'
      puts "Markdown report generated: #{result[:markdown_path]}"
    end
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    print_usage
    exit 1
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end