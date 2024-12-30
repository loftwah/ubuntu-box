#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'fileutils'
require 'time'
require 'optparse'
require 'yaml'
require 'dotenv'

# Load environment variables from .env file
Dotenv.load

class WeatherAnalytics
  PERIODS = {
    'day' => 1,
    'week' => 7,
    'fortnight' => 14,
    'month' => 30
  }

  def initialize(options = {})
    load_config(options[:config_file])
    
    @location = options[:location] || 
                ENV['DEFAULT_LOCATION'] || 
                @config['default_location'] || 
                'Melbourne,AU'
    
    @api_key = ENV['OPENWEATHER_API_KEY'] || 
               @config['api_key'] || 
               raise("API key is required in either config file or OPENWEATHER_API_KEY environment variable")
               

    @output_format = options[:format] || 
                    ENV['DEFAULT_FORMAT'] || 
                    'stdout'
    @period = options[:period] || 
              ENV['DEFAULT_PERIOD'] || 
              'day'
    @report_dir = options[:output_dir] || 
                  ENV['OUTPUT_DIR'] || 
                  "reports/weather"
    
    FileUtils.mkdir_p(@report_dir) if @output_format != 'stdout'
  end

  private

  def load_config(config_file)
    config_path = config_file || File.join(Dir.home, '.weather_config.yml')
    example_config_path = 'weather_config.yml.example'

    if File.exist?(config_path)
      @config = YAML.load_file(config_path)
    elsif File.exist?(example_config_path)
      @config = YAML.load_file(example_config_path)
    else
      create_example_config
      @config = {'default_location' => 'Melbourne,AU'}
    end
  end

  def create_example_config
    example_config = {
      'api_key' => 'your_api_key_here',
      'default_location' => 'Melbourne,AU',
      'locations' => [
        {'name' => 'Melbourne', 'country' => 'AU'},
        {'name' => 'Sydney', 'country' => 'AU'}
      ]
    }

    File.write('weather_config.yml.example', example_config.to_yaml)
  end

  def api_params
    {
      units: ENV['UNITS'] || @config['units'] || 'metric',
      lang: ENV['LANGUAGE'] || @config['language'] || 'en'
    }
  end

  def fetch_weather_data
    case @period
    when 'day'
      fetch_current_weather
    else
      fetch_forecast
    end
  end

  def fetch_current_weather
    url = "https://api.openweathermap.org/data/2.5/weather"
    query = {
      q: @location,
      appid: @api_key,
      units: api_params[:units],
      lang: api_params[:lang]
    }
    
    response = HTTParty.get(url, query: query)
    
    validate_response(response)
    
    # Fetch UV data separately as it requires different endpoint
    uv_response = HTTParty.get(
      "https://api.openweathermap.org/data/2.5/uvi",
      query: {
        lat: response['coord']['lat'],
        lon: response['coord']['lon'],
        appid: @api_key
      }
    )
    
    validate_response(uv_response)
    
    {
      timestamp: Time.now.iso8601,
      location: @location,
      current: format_current_weather(response, uv_response)
    }
  end

  def fetch_forecast
    response = HTTParty.get(
      "https://api.openweathermap.org/data/2.5/forecast",
      query: {
        q: @location,
        appid: @api_key,
        units: api_params[:units],
        lang: api_params[:lang],
        cnt: PERIODS[@period] * 8  # API returns data in 3-hour intervals
      }
    )
    
    validate_response(response)
    
    {
      timestamp: Time.now.iso8601,
      location: @location,
      forecast: format_forecast(response)
    }
  end

  def validate_response(response)
    unless response.success?
      error_message = response['message'] || 'Unknown error'

      raise "API request failed: #{error_message}"
    end
  end

  def format_current_weather(weather_data, uv_data)
    {
      temperature: {
        current: weather_data['main']['temp'],
        feels_like: weather_data['main']['feels_like'],
        min: weather_data['main']['temp_min'],
        max: weather_data['main']['temp_max']
      },
      humidity: weather_data['main']['humidity'],
      pressure: weather_data['main']['pressure'],
      wind: {
        speed: weather_data['wind']['speed'],
        direction: weather_data['wind']['deg']
      },
      conditions: weather_data['weather'].first['description'],
      uv_index: uv_data['value'],
      sunrise: Time.at(weather_data['sys']['sunrise']).strftime('%H:%M'),
      sunset: Time.at(weather_data['sys']['sunset']).strftime('%H:%M'),
      visibility: weather_data['visibility']
    }
  end

  def format_forecast(forecast_data)
    forecast_data['list'].map do |interval|
      {
        timestamp: Time.at(interval['dt']).strftime('%Y-%m-%d %H:%M'),
        temperature: {
          value: interval['main']['temp'],
          feels_like: interval['main']['feels_like']
        },
        humidity: interval['main']['humidity'],
        pressure: interval['main']['pressure'],
        wind: {
          speed: interval['wind']['speed'],
          direction: interval['wind']['deg']
        },
        conditions: interval['weather'].first['description'],
        precipitation_probability: interval['pop']
      }
    end
  end

  public

  def generate_report
    data = fetch_weather_data
    
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
    filename = "#{Time.now.strftime('%Y%m%d')}_#{@location.downcase.gsub(',', '_')}_#{@period}.json"
    json_file = File.join(@report_dir, filename)
    File.write(json_file, JSON.pretty_generate(data))
    { json_path: json_file, data: data }
  end

  def output_markdown(data)
    markdown = generate_markdown_report(data)
    filename = "#{Time.now.strftime('%Y%m%d')}_#{@location.downcase.gsub(',', '_')}_#{@period}.md"
    md_file = File.join(@report_dir, filename)
    File.write(md_file, markdown)
    { markdown_path: md_file, data: data }
  end

  def output_stdout(data)
    puts generate_markdown_report(data)
    { data: data }
  end

  def generate_markdown_report(data)
    if @period == 'day'
      generate_current_weather_markdown(data)
    else
      generate_forecast_markdown(data)
    end
  end

  def generate_current_weather_markdown(data)
    weather = data[:current]
    
    <<~MARKDOWN
      # Weather Report for #{data[:location]}

      Generated on: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}

      ## Current Conditions

      🌡️ **Temperature**
      - Current: #{weather[:temperature][:current]}°C
      - Feels like: #{weather[:temperature][:feels_like]}°C
      - Today's min: #{weather[:temperature][:min]}°C
      - Today's max: #{weather[:temperature][:max]}°C

      ☀️ **Sun & UV**
      - UV Index: #{weather[:uv_index]} #{uv_risk_level(weather[:uv_index])}
      - Sunrise: #{weather[:sunrise]}
      - Sunset: #{weather[:sunset]}

      💨 **Wind & Atmosphere**
      - Wind Speed: #{weather[:wind][:speed]} m/s
      - Wind Direction: #{wind_direction(weather[:wind][:direction])}
      - Humidity: #{weather[:humidity]}%
      - Pressure: #{weather[:pressure]} hPa
      - Visibility: #{weather[:visibility] / 1000.0} km

      🌤️ **Conditions**
      - #{weather[:conditions].capitalize}
    MARKDOWN
  end

  def generate_forecast_markdown(data)
    # First, group forecasts by day to find daily highs and lows
    daily_stats = {}
    
    data[:forecast].each do |interval|
      date = interval[:timestamp].split(' ')[0]
      temp = interval[:temperature][:value]
      
      daily_stats[date] ||= {
        min: Float::INFINITY,
        max: -Float::INFINITY
      }
      
      daily_stats[date][:min] = temp if temp < daily_stats[date][:min]
      daily_stats[date][:max] = temp if temp > daily_stats[date][:max]
    end
    
    # Generate the markdown
    <<~MARKDOWN
      # #{@period.capitalize} Weather Forecast for #{data[:location]}

      Generated on: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}

      ## Daily Temperature Summary

      #{format_daily_summary(daily_stats)}

      ## Detailed Forecast

      #{format_forecast_intervals(data[:forecast])}
    MARKDOWN
  end

  def format_daily_summary(daily_stats)
    daily_stats.map do |date, stats|
      "### #{date}\n" \
      "- High: #{stats[:max].round(1)}°C\n" \
      "- Low: #{stats[:min].round(1)}°C"
    end.join("\n\n")
  end

  def format_forecast_intervals(forecast)
    forecast.map do |interval|
      <<~INTERVAL
        ### #{interval[:timestamp]}

        - Temperature: #{interval[:temperature][:value]}°C (Feels like: #{interval[:temperature][:feels_like]}°C)
        - Conditions: #{interval[:conditions].capitalize}
        - Wind: #{interval[:wind][:speed]} m/s #{wind_direction(interval[:wind][:direction])}
        - Humidity: #{interval[:humidity]}%
        - Chance of Precipitation: #{(interval[:precipitation_probability] * 100).round}%
      INTERVAL
    end.join("\n")
  end

  def uv_risk_level(uv_index)
    case uv_index
    when 0..2 then '(Low)'
    when 3..5 then '(Moderate)'
    when 6..7 then '(High)'
    when 8..10 then '(Very High)'
    else '(Extreme)'
    end
  end

  def wind_direction(degrees)
    directions = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW]
    index = ((degrees + 11.25) % 360 / 22.5).floor
    directions[index]
  end
end

if __FILE__ == $0
  def print_usage
    puts <<~USAGE
      Weather Analytics Script

      Usage: #{File.basename($0)} [options]

      Options:
          -l, --location LOCATION    Location (format: city,country_code)
          -p, --period PERIOD        Period: day, week, fortnight, month (default: day)
          -f, --format FORMAT        Output format: stdout, markdown, json (default: stdout)
          -o, --output-dir DIR       Output directory (default: reports/weather)
          -c, --config FILE         Config file path (default: ~/.weather_config.yml)
          -h, --help                Show this help message

      Examples:
          # Default usage (current weather in Melbourne)
          #{File.basename($0)}

          # Weekly forecast for Sydney
          #{File.basename($0)} -l Sydney,AU -p week

          # Current weather in JSON format
          #{File.basename($0)} -f json

          # Monthly forecast with custom output directory
          #{File.basename($0)} -p month -o /custom/path

      Note: API key must be set in config file or OPENWEATHER_API_KEY environment variable
    USAGE
  end

  options = {
    format: 'stdout',
    period: 'day',
    output_dir: 'reports/weather'
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"

    opts.on("-l", "--location LOCATION", "Location (format: city,country_code)") do |l|
      options[:location] = l
    end

    opts.on("-p", "--period PERIOD", WeatherAnalytics::PERIODS.keys,
            "Period: #{WeatherAnalytics::PERIODS.keys.join(', ')} (default: #{options[:period]})") do |p|
      options[:period] = p
    end

    opts.on("-f", "--format FORMAT", %w[stdout markdown json],
            "Output format: stdout, markdown, json (default: #{options[:format]})") do |f|
      options[:format] = f
    end

    opts.on("-o", "--output-dir DIR", "Output directory (default: #{options[:output_dir]})") do |d|
      options[:output_dir] = d
    end

    opts.on("-c", "--config FILE", "Config file path") do |c|
      options[:config_file] = c
    end

    opts.on("-h", "--help", "Show this help message") do
      print_usage
      exit
    end
  end

  begin
    parser.parse!

    weather = WeatherAnalytics.new(options)
    result = weather.generate_report

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