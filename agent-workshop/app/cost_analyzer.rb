require "json"
require_relative "./main"

# Mock cost data
MOCK_COSTS = {
  "current_month" => {
    "total" => 12350.45,
    "services" => {
      "EC2" => 5200.30,
      "RDS" => 3100.75,
      "S3" => 950.20,
      "Lambda" => 250.15,
      "Other" => 2849.05
    },
    "unusual_spending" => [
      {
        "service" => "EC2",
        "amount" => 800.50,
        "reason" => "Unexpected spike in instance usage in us-west-2"
      }
    ]
  },
  "previous_month" => {
    "total" => 10200.30,
    "services" => {
      "EC2" => 4500.20,
      "RDS" => 2800.50,
      "S3" => 850.15,
      "Lambda" => 200.10,
      "Other" => 1849.35
    }
  }
}

def cost_analyzer_handler(event:, context:)
  query = event.dig("queryStringParameters", "analysis") || "overview"
  
  begin
    case query.downcase
    when "overview"
      prompt = <<~PROMPT
        You are an AWS cost analysis expert. Please provide a natural, conversational summary of the following costs:

        Current month total: $#{MOCK_COSTS["current_month"]["total"]}
        Previous month total: $#{MOCK_COSTS["previous_month"]["total"]}

        Current month breakdown:
        #{MOCK_COSTS["current_month"]["services"].map { |service, cost| "- #{service}: $#{cost}" }.join("\n")}

        Notable changes:
        - Month-over-month change: #{((MOCK_COSTS["current_month"]["total"] - MOCK_COSTS["previous_month"]["total"]) / MOCK_COSTS["previous_month"]["total"] * 100).round(1)}%
        
        #{
          if MOCK_COSTS["current_month"]["unusual_spending"]&.any?
            "Unusual spending:\n" + MOCK_COSTS["current_month"]["unusual_spending"].map { |alert| 
              "- #{alert["service"]}: $#{alert["amount"]} (#{alert["reason"]})"
            }.join("\n")
          end
        }

        Please analyze these costs and suggest potential optimizations.
      PROMPT

      summary = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          analysis: summary,
          raw_data: MOCK_COSTS
        })
      }
      
    when "savings"
      prompt = <<~PROMPT
        You are an AWS cost optimization expert. Based on the following service costs, suggest specific ways to reduce spending:

        Current services:
        #{MOCK_COSTS["current_month"]["services"].map { |service, cost| "- #{service}: $#{cost}" }.join("\n")}

        Focus on the top spending areas and provide actionable recommendations for cost reduction.
      PROMPT

      recommendations = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          recommendations: recommendations,
          top_services: MOCK_COSTS["current_month"]["services"].sort_by { |_, cost| -cost }.to_h
        })
      }
      
    else
      {
        statusCode: 400,
        body: JSON.generate({
          error: "Invalid analysis type. Supported types: overview, savings"
        })
      }
    end
    
  rescue StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({
        error: "Failed to analyze costs",
        details: e.message
      })
    }
  end
end

# Test helper for local development
if __FILE__ == $0
  # Test overview analysis
  test_event = {
    "queryStringParameters" => { "analysis" => "overview" }
  }
  result = cost_analyzer_handler(event: test_event, context: {})
  puts "Cost Overview Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test savings analysis
  test_event = {
    "queryStringParameters" => { "analysis" => "savings" }
  }
  result = cost_analyzer_handler(event: test_event, context: {})
  puts "\nSavings Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end