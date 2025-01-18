require "json"
require "time"
require_relative "./main"

# Mock GitHub and Jira data
MOCK_DATA = {
  "github" => {
    "pull_requests" => [
      {
        "title" => "Add Kubernetes autoscaling",
        "author" => "devops-alice",
        "status" => "merged",
        "created_at" => (Time.now - 86400 * 2).iso8601,
        "merged_at" => (Time.now - 86400 * 1).iso8601,
        "comments" => 5,
        "changes" => "+350/-120"
      },
      {
        "title" => "Fix memory leak in worker service",
        "author" => "backend-bob",
        "status" => "open",
        "created_at" => (Time.now - 86400 * 1).iso8601,
        "comments" => 3,
        "changes" => "+25/-15"
      }
    ],
    "commits" => [
      {
        "sha" => "abc123",
        "author" => "devops-alice",
        "message" => "Update deployment configuration",
        "date" => (Time.now - 86400 * 3).iso8601
      },
      {
        "sha" => "def456",
        "author" => "backend-bob",
        "message" => "Optimize database queries",
        "date" => (Time.now - 86400 * 2).iso8601
      }
    ]
  },
  "jira" => {
    "tickets" => [
      {
        "key" => "OPS-123",
        "title" => "Implement high availability for Redis cluster",
        "status" => "In Progress",
        "assignee" => "devops-alice",
        "priority" => "High",
        "created_at" => (Time.now - 86400 * 5).iso8601
      },
      {
        "key" => "SEC-456",
        "title" => "Security audit findings remediation",
        "status" => "Done",
        "assignee" => "security-charlie",
        "priority" => "Critical",
        "created_at" => (Time.now - 86400 * 7).iso8601,
        "completed_at" => (Time.now - 86400 * 1).iso8601
      }
    ],
    "sprints" => [
      {
        "name" => "Sprint 45",
        "status" => "Active",
        "start_date" => (Time.now - 86400 * 7).iso8601,
        "end_date" => (Time.now + 86400 * 7).iso8601,
        "completed_points" => 34,
        "total_points" => 55
      }
    ]
  }
}

def gh_jira_report_handler(event:, context:)
  report_type = event.dig("queryStringParameters", "type") || "weekly"
  
  begin
    case report_type
    when "weekly"
      prompt = <<~PROMPT
        You are a technical project manager. Generate a weekly development summary based on this data:

        GitHub Activity:
        Pull Requests:
        #{MOCK_DATA["github"]["pull_requests"].map { |pr| 
          "- #{pr["title"]} by #{pr["author"]} (#{pr["status"]}, #{pr["comments"]} comments)"
        }.join("\n")}

        Recent Commits:
        #{MOCK_DATA["github"]["commits"].map { |commit|
          "- #{commit["message"]} by #{commit["author"]}"
        }.join("\n")}

        Jira Updates:
        Tickets:
        #{MOCK_DATA["jira"]["tickets"].map { |ticket|
          "- #{ticket["key"]}: #{ticket["title"]} (#{ticket["status"]}, #{ticket["priority"]})"
        }.join("\n")}

        Sprint Progress:
        #{MOCK_DATA["jira"]["sprints"].map { |sprint|
          "#{sprint["name"]}: #{sprint["completed_points"]}/#{sprint["total_points"]} points completed"
        }.join("\n")}

        Please provide a concise summary of the week's development progress, highlighting key achievements and ongoing work.
      PROMPT

      summary = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          weekly_summary: summary,
          raw_data: MOCK_DATA
        })
      }

    when "metrics"
      # Calculate development metrics
      metrics = {
        pr_velocity: MOCK_DATA["github"]["pull_requests"].length,
        commit_count: MOCK_DATA["github"]["commits"].length,
        active_tickets: MOCK_DATA["jira"]["tickets"].count { |t| t["status"] != "Done" },
        sprint_progress: MOCK_DATA["jira"]["sprints"].first["completed_points"].to_f / 
                        MOCK_DATA["jira"]["sprints"].first["total_points"] * 100
      }

      prompt = <<~PROMPT
        You are a development metrics analyst. Please analyze these development metrics:

        - Pull Request Velocity: #{metrics[:pr_velocity]} PRs this week
        - Commit Activity: #{metrics[:commit_count]} commits
        - Active Tickets: #{metrics[:active_tickets]}
        - Sprint Progress: #{metrics[:sprint_progress].round(1)}%

        Please provide insights about team velocity and suggest any areas for improvement.
      PROMPT

      analysis = bedrock_invoke(prompt)
      {
        statusCode: 200,
        body: JSON.generate({
          metrics_analysis: analysis,
          metrics: metrics
        })
      }

    else
      {
        statusCode: 400,
        body: JSON.generate({
          error: "Invalid report type. Supported types: weekly, metrics"
        })
      }
    end
    
  rescue StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({
        error: "Failed to generate report",
        details: e.message
      })
    }
  end
end

# Test helper for local development
if __FILE__ == $0
  # Test weekly report
  test_event = {
    "queryStringParameters" => { "type" => "weekly" }
  }
  result = gh_jira_report_handler(event: test_event, context: {})
  puts "Weekly Development Report:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
  
  # Test metrics report
  test_event = {
    "queryStringParameters" => { "type" => "metrics" }
  }
  result = gh_jira_report_handler(event: test_event, context: {})
  puts "\nDevelopment Metrics Analysis:"
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end