require "json"
require_relative "./main"

# Mock usage and alert data
MOCK_USAGE_DATA = {
  "metrics" => {
    "cpu" => [
      { "timestamp" => Time.now - 3600, "value" => 85.5, "unit" => "Percent" },
      { "timestamp" => Time.now - 2400, "value" => 90.2, "unit" => "Percent" },
      { "timestamp" => Time.now - 1200, "value" => 95.8, "unit" => "Percent" }
    ],
    "memory" => [
      { "timestamp" => Time.now - 3600, "value" => 75.5, "unit" => "Percent" },
      { "timestamp" => Time.now - 2400, "value" => 82.3, "unit" => "Percent" },
      { "timestamp" => Time.now - 1200, "value" => 88.7, "unit" => "Percent" }
    ],
    "disk" => [
      { "timestamp" => Time.now - 3600, "value" => 65.5, "unit" => "Percent" },
      { "timestamp" => Time.now - 2400, "value" => 67.8, "unit" => "Percent" },
      { "timestamp" => Time.now - 1200, "value" => 72.1, "unit" => "Percent" }
    ]
  },
  "alarms" => [
    {
      "name" => "HighCPUUtilization",
      "status" => "ALARM",
      "metric" => "cpu",
      "threshold" => 80,
      "evaluation_periods" => 3,
      "triggered_at" => Time.now - 1200
    },
    {
      "name" => "HighMemoryUsage",
      "status" => "ALARM",
      "metric" => "memory",
      "threshold" => 85,
      "evaluation_periods" => 2,
      "triggered_at" => Time.now - 1200
    }
  ]
}

def usage_agent_handler(event:, context:)
  action = event.dig("queryStringParameters", "action") || "analyze"
  
  begin
    case action
    when "analyze"
      # Analyze current usage patterns and active alarms
      metrics_summary = MOCK_USAGE_DATA["metrics"].map { |metric, data|
        current = data.last["value"]
        trend = current - data.first["value"]
        "#{metric.upcase}: Currently #{current}% (#{trend > 0 ? '+' : ''}#{trend.round(1)}% change)"
      }.join("\n")

      alarms_summary = MOCK_USAGE_DATA["alarms"].map { |alarm|
        "#{alarm['name']}: #{alarm['status']} (threshold: #{alarm['threshold']}%)"
      }.join("\n")

      prompt = <<~PROMPT
        You are a systems monitoring expert. Analyze this usage data and active alarms:

        Current Metrics:
        #{metrics_summary}

        Active Alarms:
        #{alarms_summary}

        Please provide:
        1. An assessment of the current system state
        2. Potential causes for any issues
        3. Recommended actions
        4. Priority level for response
      PROMPT

      analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          analysis: analysis,
          current_metrics: MOCK_USAGE_DATA["metrics"].transform_values(&:last),
          active_alarms: MOCK_USAGE_DATA["alarms"]
        })
      }

    when "forecast"
      # Generate usage forecast based on trends
      metrics_trends = MOCK_USAGE_DATA["metrics"].transform_values do |data|
        first = data.first["value"]
        last = data.last["value"]
        hourly_change = (last - first) / 3.0  # 3 hours of data
        {
          current: last,
          hourly_change: hourly_change,
          projected_4h: [100, last + (hourly_change * 4)].min
        }
      end

      prompt = <<~PROMPT
        You are a capacity planning expert. Analyze these usage trends:

        #{metrics_trends.map { |metric, data|
          "#{metric.upcase}:\n" \
          "Current: #{data[:current].round(1)}%\n" \
          "Hourly change: #{data[:hourly_change] > 0 ? '+' : ''}#{data[:hourly_change].round(1)}%\n" \
          "4-hour projection: #{data[:projected_4h].round(1)}%"
        }.join("\n\n")}

        Please provide:
        1. Usage forecast for the next 4 hours
        2. Resource scaling recommendations
        3. Potential bottlenecks to address
        4. Long-term capacity planning suggestions
      PROMPT

      forecast = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          forecast: forecast,
          trends: metrics_trends
        })
      }

    when "remediate"
      # Suggest remediation steps for active alarms
      active_alarms = MOCK_USAGE_DATA["alarms"].select { |a| a["status"] == "ALARM" }
      
      prompt = <<~PROMPT
        You are a system administrator. Suggest remediation steps for these active alarms:

        #{active_alarms.map { |alarm|
          "#{alarm['name']}:\n" \
          "Metric: #{alarm['metric']}\n" \
          "Threshold: #{alarm['threshold']}%\n" \
          "Current Value: #{MOCK_USAGE_DATA['metrics'][alarm['metric']].last['value']}%"
        }.join("\n\n")}

        Please provide:
        1. Immediate actions to take
        2. Investigation steps
        3. Long-term fixes
        4. Prevention strategies
      PROMPT

      remediation = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          remediation_plan: remediation,
          active_alarms: active_alarms
        })
      }

    else
      {
        statusCode: 400,
        body: JSON.generate({
          error: "Invalid action. Supported actions: analyze, forecast, remediate"
        })
      }
    end
    
  rescue StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({
        error: "Failed to process usage data",
        details: e.message
      })
    }
  end
end

# Test helper for local development
if __FILE__ == $0
  # Test usage analysis
  test_event = {
    "queryStringParameters" => { "action" => "analyze" }
  }
  result = usage_agent_handler(event: test_event, context: {})
  puts "Usage Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test usage forecast
  test_event = {
    "queryStringParameters" => { "action" => "forecast" }
  }
  result = usage_agent_handler(event: test_event, context: {})
  puts "\nUsage Forecast:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test remediation suggestions
  test_event = {
    "queryStringParameters" => { "action" => "remediate" }
  }
  result = usage_agent_handler(event: test_event, context: {})
  puts "\nRemediation Plan:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end