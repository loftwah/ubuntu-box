require "json"
require "base64"
require_relative "./main"

# Mock CI/CD and infrastructure data
MOCK_ADVANCED_DATA = {
  "ci_cd" => {
    "pipeline_logs" => [
      {
        "pipeline": "main-service-deploy",
        "stage": "test",
        "status": "failed",
        "logs": [
          "[ERROR] Test failed: api_integration_spec.rb:45",
          "Expected response code 200, got 503",
          "Service dependency 'auth-service' unavailable"
        ]
      },
      {
        "pipeline": "auth-service-deploy",
        "stage": "deploy",
        "status": "success",
        "logs": [
          "Deploying to production...",
          "Health checks passed",
          "Migration completed successfully"
        ]
      }
    ]
  },
  "infrastructure" => {
    "service_map": {
      "nodes": [
        { "id": "frontend", "type": "service", "dependencies": ["api-gateway"] },
        { "id": "api-gateway", "type": "service", "dependencies": ["auth-service", "main-service"] },
        { "id": "auth-service", "type": "service", "dependencies": ["user-db"] },
        { "id": "main-service", "type": "service", "dependencies": ["main-db", "cache"] },
        { "id": "user-db", "type": "database", "dependencies": [] },
        { "id": "main-db", "type": "database", "dependencies": [] },
        { "id": "cache", "type": "cache", "dependencies": [] }
      ]
    }
  },
  "monitoring" => {
    "alerts": [
      {
        "service": "main-service",
        "metric": "latency_p95",
        "threshold": 200,
        "current_value": 250,
        "duration": "15m"
      },
      {
        "service": "auth-service",
        "metric": "error_rate",
        "threshold": 1,
        "current_value": 2.5,
        "duration": "5m"
      }
    ]
  }
}

def advanced_features_handler(event:, context:)
  feature = event.dig("queryStringParameters", "feature") || "ci_cd"
  
  begin
    case feature
    when "ci_cd"
      prompt = <<~PROMPT
        You are a CI/CD expert. Analyze these pipeline logs and provide insights:

        #{MOCK_ADVANCED_DATA["ci_cd"]["pipeline_logs"].map { |pipeline|
          "Pipeline: #{pipeline[:pipeline]}\n" \
          "Stage: #{pipeline[:stage]}\n" \
          "Status: #{pipeline[:status]}\n" \
          "Logs:\n#{pipeline[:logs].map { |log| "  #{log}" }.join("\n")}"
        }.join("\n\n")}

        Please provide a summary of the pipeline status and recommend actions to resolve any issues.
      PROMPT

      analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          ci_cd_analysis: analysis,
          pipeline_status: MOCK_ADVANCED_DATA["ci_cd"]["pipeline_logs"].map { |p| 
            { pipeline: p[:pipeline], status: p[:status] }
          }
        })
      }

    when "service_map"
      prompt = <<~PROMPT
        You are a system architect. Analyze this service dependency map:

        Services:
        #{MOCK_ADVANCED_DATA["infrastructure"]["service_map"]["nodes"].map { |node|
          "#{node[:id]} (#{node[:type]}) depends on: #{node[:dependencies].join(", ")}"
        }.join("\n")}

        Please identify potential bottlenecks and suggest architectural improvements.
      PROMPT

      analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          architecture_analysis: analysis,
          service_map: MOCK_ADVANCED_DATA["infrastructure"]["service_map"]
        })
      }

    when "alerts"
      prompt = <<~PROMPT
        You are a systems reliability engineer. Analyze these monitoring alerts:

        #{MOCK_ADVANCED_DATA["monitoring"]["alerts"].map { |alert|
          "Service: #{alert[:service]}\n" \
          "Metric: #{alert[:metric]}\n" \
          "Current: #{alert[:current_value]} (threshold: #{alert[:threshold]})\n" \
          "Duration: #{alert[:duration]}"
        }.join("\n\n")}

        Please provide an incident assessment and recommend immediate actions.
      PROMPT

      analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          alert_analysis: analysis,
          active_alerts: MOCK_ADVANCED_DATA["monitoring"]["alerts"]
        })
      }

    else
      {
        statusCode: 400,
        body: JSON.generate({
          error: "Invalid feature type. Supported types: ci_cd, service_map, alerts"
        })
      }
    end
    
  rescue StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({
        error: "Failed to process advanced feature",
        details: e.message
      })
    }
  end
end

# Test helper for local development
if __FILE__ == $0
  # Test CI/CD analysis
  test_event = {
    "queryStringParameters" => { "feature" => "ci_cd" }
  }
  result = advanced_features_handler(event: test_event, context: {})
  puts "CI/CD Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test service map analysis
  test_event = {
    "queryStringParameters" => { "feature" => "service_map" }
  }
  result = advanced_features_handler(event: test_event, context: {})
  puts "\nService Map Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test alerts analysis
  test_event = {
    "queryStringParameters" => { "feature" => "alerts" }
  }
  result = advanced_features_handler(event: test_event, context: {})
  puts "\nAlerts Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end