require "json"
require_relative "./main"

# Mock security findings and best practices
MOCK_SECURITY_DATA = {
  "findings" => [
    {
      "severity": "HIGH",
      "category": "IAM",
      "description": "IAM users found with long-lasting access keys (>90 days)",
      "affected_resources": ["user/developer1", "user/developer2"],
      "recommendation": "Rotate access keys and implement automatic key rotation"
    },
    {
      "severity": "MEDIUM",
      "category": "S3",
      "description": "Public read access enabled on non-website buckets",
      "affected_resources": ["bucket/logs-storage", "bucket/backup-data"],
      "recommendation": "Review bucket policies and remove unnecessary public access"
    },
    {
      "severity": "LOW",
      "category": "EC2",
      "description": "Instances without required tags",
      "affected_resources": ["i-0123456789abcdef0", "i-0123456789abcdef1"],
      "recommendation": "Apply mandatory tags for better resource tracking"
    }
  ],
  "compliance" => {
    "cis_benchmark": {
      "status": "PARTIAL",
      "pass_rate": 85,
      "failed_controls": [
        "1.4 - Ensure access keys are rotated every 90 days",
        "2.1.1 - Ensure all S3 buckets employ encryption-at-rest"
      ]
    },
    "pci_dss": {
      "status": "COMPLIANT",
      "pass_rate": 98,
      "failed_controls": []
    }
  }
}

def security_analyzer_handler(event:, context:)
  query = event.dig("queryStringParameters", "type") || "overview"
  
  begin
    case query.downcase
    when "overview"
      prompt = <<~PROMPT
        You are a cloud security expert. Please provide a clear summary of the following security findings:

        Findings by severity:
        #{MOCK_SECURITY_DATA["findings"].group_by { |f| f[:severity] }.map { |sev, findings| 
          "#{sev}: #{findings.length} finding(s)"
        }.join("\n")}

        Compliance Status:
        #{MOCK_SECURITY_DATA["compliance"].map { |framework, data| 
          "- #{framework.upcase}: #{data["status"]} (#{data["pass_rate"]}% pass rate)"
        }.join("\n")}

        Please provide a high-level security assessment and prioritized recommendations.
      PROMPT

      assessment = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          assessment: assessment,
          findings_count: MOCK_SECURITY_DATA["findings"].length,
          compliance_status: MOCK_SECURITY_DATA["compliance"]
        })
      }

    when "detailed"
      prompt = <<~PROMPT
        You are a cloud security expert. Please analyze these security findings in detail:

        #{MOCK_SECURITY_DATA["findings"].map { |finding|
          "#{finding[:severity]} - #{finding[:category]}: #{finding[:description]}\n" \
          "Affected: #{finding[:affected_resources].join(", ")}\n" \
          "Recommendation: #{finding[:recommendation]}"
        }.join("\n\n")}

        Please provide detailed remediation steps for each finding, prioritizing by severity.
      PROMPT

      detailed_analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          detailed_analysis: detailed_analysis,
          raw_findings: MOCK_SECURITY_DATA["findings"]
        })
      }

    when "compliance"
      prompt = <<~PROMPT
        You are a compliance expert. Please analyze the following compliance status:

        #{MOCK_SECURITY_DATA["compliance"].map { |framework, data|
          "#{framework.upcase}:\n" \
          "Status: #{data["status"]}\n" \
          "Pass Rate: #{data["pass_rate"]}%\n" \
          "Failed Controls:\n#{data["failed_controls"].map { |c| "- #{c}" }.join("\n")}"
        }.join("\n\n")}

        Please provide recommendations to improve compliance posture.
      PROMPT

      compliance_analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          compliance_analysis: compliance_analysis,
          compliance_data: MOCK_SECURITY_DATA["compliance"]
        })
      }

    else
      {
        statusCode: 400,
        body: JSON.generate({
          error: "Invalid analysis type. Supported types: overview, detailed, compliance"
        })
      }
    end
    
  rescue StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({
        error: "Failed to analyze security status",
        details: e.message
      })
    }
  end
end

# Test helper for local development
if __FILE__ == $0
  # Test overview analysis
  test_event = {
    "queryStringParameters" => { "type" => "overview" }
  }
  result = security_analyzer_handler(event: test_event, context: {})
  puts "Security Overview Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test detailed analysis
  test_event = {
    "queryStringParameters" => { "type" => "detailed" }
  }
  result = security_analyzer_handler(event: test_event, context: {})
  puts "\nDetailed Security Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test compliance analysis
  test_event = {
    "queryStringParameters" => { "type" => "compliance" }
  }
  result = security_analyzer_handler(event: test_event, context: {})
  puts "\nCompliance Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end