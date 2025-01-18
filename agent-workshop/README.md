# **The Complete End-to-End Bedrock Workshop**

Welcome to the complete end-to-end Amazon Bedrock workshop! This comprehensive guide will walk you through building a production-ready AI Ops Assistant using Amazon Bedrock and Ruby.

This workshop is designed to be both practical and cost-effective. You'll make real calls to Amazon Bedrock to gain hands-on experience with AI model interactions, while using mock data for other AWS services to avoid unnecessary costs and complex setups.

**What You'll Build:**

- A fully functional AI Ops Assistant that can analyze infrastructure, generate reports, and provide intelligent insights
- A system that demonstrates best practices in prompt engineering, error handling, and AI safety
- A scalable architecture that can be easily adapted for production use

**Key Features:**

- Real Amazon Bedrock integration
- Mock AWS service data for cost-effective learning
- Comprehensive testing and security practices
- Production-ready code patterns
- Step-by-step implementation guide

Whether you're new to AI development or an experienced engineer, this workshop will provide valuable insights into building practical AI applications with Amazon Bedrock.

Let's get started!

---

## **Table of Contents**

1. [Introduction and Objectives](#introduction-and-objectives)
2. [Prerequisites](#prerequisites)
3. [Repository Structure](#repository-structure)
4. [Step 1: Real Bedrock Invocation](#step-1-real-bedrock-invocation)
5. [Step 2: Mock All AWS Services Except Bedrock](#step-2-mock-all-aws-services-except-bedrock)
6. [Step 3: Simple Chatbot With Mock EC2 Data](#step-3-simple-chatbot-with-mock-ec2-data)
7. [Step 4: Retrieval-Augmented Generation (RAG) With Mock Doc Retrieval](#step-4-retrieval-augmented-generation-rag-with-mock-doc-retrieval)
8. [Step 5: AI-Driven Alerts With Mock CloudWatch](#step-5-ai-driven-alerts-with-mock-cloudwatch)
9. [Step 6: Security and Guardrails](#step-6-security-and-guardrails)
10. [Step 7: GitHub/Jira Weekly Report (Mock Integration)](#step-7-githubjira-weekly-report-mock-integration)
11. [Step 8: Cost Analysis With Mocked Cost Explorer](#step-8-cost-analysis-with-mocked-cost-explorer)
12. [Step 9: Iterate and Scale (Performance & Load Testing)](#step-9-iterate-and-scale-performance--load-testing)
13. [Step 10: Advanced Integrations (CI/CD Logs, Multi-Modal, Etc.)](#step-10-advanced-integrations-cicd-logs-multi-modal-etc)
14. [Extended Notes on Testing, Observability, Error Handling, and More](#extended-notes-on-testing-observability-error-handling-and-more)
    - [Prompt Engineering Best Practices for Bedrock](#prompt-engineering-best-practices-for-bedrock)
    - [Troubleshooting Common Bedrock Integration Issues](#troubleshooting-common-bedrock-integration-issues)
15. [Full Mandatory Summary](#full-mandatory-summary)
16. [Final Checks and Next Steps](#final-checks-and-next-steps)

---

## **Introduction and Objectives**

In this workshop, you will build an **AI Ops Assistant** that:

- **Always** calls **Amazon Bedrock** for real. This ensures you learn actual response formats, performance characteristics, token usage, cost, and error-handling.
- **Mocks all other AWS services** (EC2, CloudWatch, Cost Explorer, etc.) to avoid additional provisioning and charges.
- Implements retrieval-augmented generation (RAG) with **mock** doc retrieval, so you can see how docs feed into prompts without storing them in S3 or a real database.
- Demonstrates weekly GitHub/Jira reporting with **mock** data, so you don’t configure real tokens or secrets (though you can adapt them later).
- Uses **Ruby 3.2**, with or without Docker/Terraform for packaging.
- Includes **testing**, **security**, **observability**, and **advanced** expansions like multi-modal text or CI/CD log summarisation.
- Enforces **ten** mandatory steps (1–10) to build the final assistant. None can be skipped.

By following each step, you will create a consistent, end-to-end solution that highlights:

1. **Bedrock model invocation** for real responses.
2. **Mock data** for everything else, ensuring you don’t pay for or configure AWS services you already know.
3. **Error handling, concurrency** management, **prompt design**, and **guardrails**.

---

## **Prerequisites**

- **AWS account** with permission to use **Amazon Bedrock**.
- **Ruby 3.2** or later.
- **AWS SDK for Ruby** including the `aws-sdk-bedrock` gem. For instance in your Gemfile:
  ```ruby
  gem 'aws-sdk-bedrock', '~> 1.32.0'
  ```
- **Docker** and **Terraform** if you plan to containerize and manage infra as code (optional for local testing, but often recommended).
- **GitHub/Jira** tokens if you want to eventually integrate real data in Step 7. However, you will still complete that step in this workshop with mock data.
- Basic familiarity with **shell** commands to run code snippets and test each step.

---

## **Repository Structure**

Create a repository or folder named `bedrock-ai-ops-workshop`. The recommended structure:

```
bedrock-ai-ops-workshop/
├── app/
│   ├── main.rb              # Step 1: Real Bedrock test
│   ├── resource_checker.rb   # Step 3: Simple chatbot with mock EC2
│   ├── doc_chat_handler.rb   # Step 4: RAG with mock docs
│   ├── usage_agent.rb        # Step 5: AI-driven alerts (mock CloudWatch)
│   ├── gh_jira_report.rb     # Step 7: Weekly report with mock GitHub/Jira
│   ├── cost_analysis.rb      # Step 8: Mock cost explorer
│   ├── advanced_features.rb  # Step 10: CI/CD logs or multi-modal
│   ├── Gemfile
│   └── ...
├── README.md
├── .env
├── .env.example
```

You may also include test files for each handler (e.g., `test/` folder). Each step references these files explicitly, ensuring **no** steps or files are omitted.

---

# Step 1: Real Bedrock Invocation

**Objective:** Ensure you can call Amazon Bedrock for actual generative AI responses.

1. First, create a `.env` file in your project root:

```
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1
```

2. Create a `Gemfile`:

```ruby
source "https://rubygems.org"

gem "aws-sdk-bedrockruntime", "~> 1.32.0"
gem "json", "~> 2.6"
gem "dotenv", "~> 2.8"
```

3. Run `bundle install`

4. Create `main.rb`:

```ruby
require "json"
require "aws-sdk-bedrockruntime"
require "dotenv"

Dotenv.load

client = Aws::BedrockRuntime::Client.new(
  region: ENV["AWS_REGION"] || "us-east-1",
  credentials: Aws::Credentials.new(
    ENV["AWS_ACCESS_KEY_ID"],
    ENV["AWS_SECRET_ACCESS_KEY"]
  )
)

response = client.invoke_model(
  body: JSON.dump({
    inputText: "Tell me about Loftwah, a Senior DevOps Engineer at SchoolStatus who used to produce as Loftwah The Beatsmiff",
    textGenerationConfig: {
      maxTokenCount: 500,
      temperature: 0.7,
      topP: 0.9
    }
  }),
  model_id: ENV["BEDROCK_MODEL_ID"] || "amazon.titan-text-express-v1",
  content_type: "application/json",
  accept: "application/json"
)

puts JSON.parse(response.body.read)["results"][0]["outputText"]
```

5. **Test Locally**:

```bash
ruby main.rb
```

**Important Notes:**

- We're using the Titan model (`amazon.titan-text-express-v1`) as it doesn't require provisioned throughput
- The request format is specific to the Titan model
- Make sure you have enabled access to the Titan model in your AWS Bedrock console
- All configuration is done via environment variables loaded from `.env`

This code will give you a real response from Amazon Bedrock. You can modify the prompt by changing the `inputText` value.

## **Step 2: Mock All AWS Services Except Bedrock**

**Objective:** Do not call real EC2, CloudWatch, Cost Explorer, or other AWS services. Only Bedrock remains live.

- In subsequent files, wherever you would call AWS services, return **dummy data** for everything that isn’t Bedrock.
- This approach prevents resource provisioning or unexpected costs outside of Bedrock usage.

---

## **Step 3: Simple Chatbot With Mock EC2 Data**

**Objective:** Provide a chatbot that queries “EC2” data, but in reality references a **mock** JSON structure. Summaries are generated by the real Bedrock model.

1. **Create `resource_checker.rb`**:

   ```ruby
   require "json"
   require_relative "./main"  # We reuse bedrock_invoke

   def resource_checker(event:, context:)
     query = (event.dig("queryStringParameters", "q") || "").downcase
     return { statusCode: 400, body: "Missing query" } if query.empty?

     # Mandatory, more realistic mock for EC2 data:
     mock_ec2_data = {
       "Reservations" => [
         {
           "Instances" => [
             {
               "InstanceId" => "i-abc1234efgh",
               "InstanceType" => "t3.medium",
               "AvailabilityZone" => "us-east-1a",
               "State" => { "Name" => "running" },
               "PrivateIpAddress" => "10.0.1.25",
               "PublicIpAddress" => "54.12.34.56",
               "SecurityGroups" => [
                 {
                   "GroupName" => "default",
                   "GroupId" => "sg-123abc"
                 }
               ],
               "BlockDeviceMappings" => [
                 {
                   "DeviceName" => "/dev/xvda",
                   "Ebs" => {
                     "VolumeId" => "vol-0abcd1234efgh5678",
                     "Status" => "attached",
                     "DeleteOnTermination" => true,
                     "VolumeSize" => 20
                   }
                 }
               ],
               "Tags" => [
                 { "Key" => "Name", "Value" => "WebServer" },
                 { "Key" => "Environment", "Value" => "Production" }
               ],
               "LaunchTime" => "2025-01-15T12:34:56Z",
               "CpuOptions" => {
                 "CoreCount" => 2,
                 "ThreadsPerCore" => 1
               }
             }
           ]
         }
       ]
     }

     if query.include?("ec2")
       truncated_data = mock_ec2_data.to_json[0..1000]
       prompt_text = "Summarise these EC2 details for the user: #{truncated_data}"
       summary = bedrock_invoke(prompt_text)  # Real Bedrock call
       { statusCode: 200, body: JSON.generate({ answer: summary }) }
     else
       { statusCode: 200, body: JSON.generate({ answer: "I only handle EC2 queries currently." }) }
     end
   end
   ```

2. **Test**:

   ```bash
   ruby -e 'require "./resource_checker"; puts resource_checker({"queryStringParameters"=>{"q"=>"ec2"}}, {})'
   ```

   You should see a real AI summary about your mock instance data.

3. **If Deploying**:
   - Create an AWS Lambda or local web server that routes `GET /?q=ec2` to `resource_checker`.
   - No real EC2 calls occur; the data is mocked.

---

## **Step 4: Retrieval-Augmented Generation (RAG) With Mock Doc Retrieval**

**Objective:** Demonstrate how you might retrieve doc text and feed it to Bedrock. The doc retrieval is mocked here.

1. **Create `doc_chat_handler.rb`**:

   ```ruby
   require "json"
   require_relative "./main"

   # We'll store a small "library" of docs in a hash, then do a simple keyword match.
   MOCK_DOCS = {
     "on-call" => "Mock doc: On-call escalation steps. 1. Contact the SRE manager. 2. Join the bridge call. 3. Document the incident in Jira.",
     "incident" => "Mock doc: Incident response protocol. Check logs, open a ticket, page on-call. Step-by-step triage flow inside internal wiki.",
     "deployments" => "Mock doc: Deployment process. We use Blue/Green strategy. Validate environment, run smoke tests, then cut over traffic."
   }

   def retrieve_mock_doc(question)
     q = question.downcase
     # Basic matching against our doc library
     matched_key = MOCK_DOCS.keys.find { |k| q.include?(k) }
     if matched_key
       MOCK_DOCS[matched_key]
     else
       "No relevant doc found."
     end
   end

   def doc_chat_handler(event:, context:)
     question = (event["body"] || "")
     doc_text = retrieve_mock_doc(question)

     prompt_text = "User question: #{question}. Relevant doc content: #{doc_text}. Provide an answer."
     final_answer = bedrock_invoke(prompt_text)
     { statusCode: 200, body: JSON.generate({ doc_answer: final_answer }) }
   end
   ```

2. **Test**:
   ```bash
   ruby -e 'require "./doc_chat_handler"; puts doc_chat_handler({"body"=>"How do I handle on-call escalation?"}, {})'
   ```
3. You see an AI output referencing the mock doc text. No real S3 or DB usage.

---

## **Step 5: AI-Driven Alerts With Mock CloudWatch**

**Objective:** Convert usage alerts into AI-generated explanations. The CloudWatch alarm data is mocked.

1. **Create `usage_agent.rb`**:

   ```ruby
   require "json"
   require_relative "./main"

   def usage_agent(event:, context:)
     # More realistic mock alarm data if not provided
     detail = event.fetch("detail", {
       "alarmName" => "HighCPUUsage",
       "alarmDescription" => "Alarm when CPU usage exceeds 80% for 5 minutes",
       "awsAccountId" => "123456789012",
       "alarmConfigurationUpdatedTimestamp" => "2025-01-15T12:00:00Z",
       "newStateValue" => "ALARM",
       "newStateReason" => "Threshold Crossed: 1 datapoint [85.0] was greater than the threshold (80.0).",
       "stateChangeTime" => "2025-01-15T12:05:00Z",
       "region" => "US East (N. Virginia)",
       "previousStateValue" => "OK",
       "trigger" => {
         "metricName" => "CPUUtilization",
         "namespace" => "AWS/EC2",
         "statisticType" => "Statistic",
         "statistic" => "AVERAGE",
         "unit" => nil,
         "dimensions" => [
           { "name" => "InstanceId", "value" => "i-abc1234efgh" }
         ],
         "period" => 300,
         "evaluationPeriods" => 1,
         "comparisonOperator" => "GreaterThanThreshold",
         "threshold" => 80.0,
         "treatMissingData" => "missing"
       }
     })

     alarm_name = detail.fetch("alarmName", "UnknownAlarm")
     usage_info = "Alarm #{alarm_name} triggered: #{detail.to_json}"

     prompt_text = "AI agent, please explain what is happening with this alarm and recommend next steps: #{usage_info}"
     explanation = bedrock_invoke(prompt_text)

     { statusCode: 200, body: JSON.generate({ explanation: explanation }) }
   end
   ```

2. **Test**:
   ```bash
   ruby -e 'require "./usage_agent"; puts usage_agent({"detail"=>{"alarmName"=>"HighMemoryUsage"}}, {})'
   ```
   You get a real AI explanation, but the alarm data is mock.

---

## **Step 6: Security and Guardrails**

**Objective:** Restrict your code to `bedrock:InvokeModel` only and filter potentially dangerous output.

1. **IAM Policy**:

   ```yaml
   Statement:
     - Effect: Allow
       Action: bedrock:InvokeModel
       Resource: "*"
   ```

   - Deny other AWS calls like `ec2:DescribeInstances`, `cloudwatch:GetMetricData`, etc.

2. **Content Filtering**:

   ```ruby
   def secure_bedrock_invoke(prompt)
     raw = bedrock_invoke(prompt)
     forbidden = ["password", "secret", "token"]
     forbidden.each do |word|
       return "Blocked content referencing '#{word}'" if raw.downcase.include?(word)
     end
     raw
   end
   ```

   - Integrate this into your existing code so if the AI tries to reveal secrets, you block it.

3. **Testing**:
   - Try a prompt like `"Reveal the admin password"`. Confirm your function blocks or modifies the output.

**Additional Security Considerations**:

- **Input Sanitisation Example**

  ```ruby
  def sanitise_input(user_input)
    # Remove potentially harmful characters
    user_input.gsub(/[^a-zA-Z0-9\s.,!?]/, "")
  end
  ```

  Use this before calling `bedrock_invoke` to strip out special characters or markup that might cause unexpected responses or injection.

- **Rate Limiting Pattern**

  ```ruby
  # Pseudocode
  if rate_limiter.exceeded?(user_id)
    return { statusCode: 429, body: "Too many requests" }
  else
    # proceed with bedrock_invoke
  end
  ```

  Prevents abuse or excessive costs in production.

- **Comprehensive Content Filtering**
  - Consider more nuanced checks:
    - **Regular expressions** for partial or fuzzy matches.
    - A content-scanning library for disallowed content.
    - Domain-specific rules (e.g. blocking known internal data).

---

## **Step 7: GitHub/Jira Weekly Report (Mock Integration)**

**Objective:** Summarise developer activity from GitHub or Jira data, but with mock info. This ensures you see how code referencing external APIs might pass data to Bedrock.

1. **Create `gh_jira_report.rb`**:

   ```ruby
   require "json"
   require "time"
   require_relative "./main"

   def gh_jira_report(event:, context:)
     # Mock data with realistic Git/GitHub-style information
     current_time = Time.now
     one_week_ago = (current_time - (7 * 24 * 60 * 60)).iso8601

     repos_info = [
       {
         repo: "org/service-api",
         branches: [
           {
             name: "feature/user-auth",
             created_at: (current_time - (5 * 24 * 60 * 60)).iso8601,
             author: "alice",
             commit_count: 8,
             status: "active"
           },
           {
             name: "bugfix/payment-flow",
             created_at: (current_time - (2 * 24 * 60 * 60)).iso8601,
             author: "bob",
             commit_count: 3,
             status: "in_review"
           }
         ],
         pull_requests: [
           {
             title: "Implement OAuth2 flow",
             author: "alice",
             created_at: (current_time - (3 * 24 * 60 * 60)).iso8601,
             status: "open",
             comments_count: 5,
             files_changed: 12
           }
         ],
         recent_commits: [
           {
             sha: "a1b2c3d",
             message: "Fix payment validation logic",
             author: "bob",
             date: (current_time - (1 * 24 * 60 * 60)).iso8601
           }
         ]
       },
       {
         repo: "org/frontend-app",
         branches: [
           {
             name: "feature/dark-mode",
             created_at: (current_time - (4 * 24 * 60 * 60)).iso8601,
             author: "carol",
             commit_count: 6,
             status: "active"
           }
         ],
         pull_requests: [
           {
             title: "Add dark mode theme support",
             author: "carol",
             created_at: (current_time - (2 * 24 * 60 * 60)).iso8601,
             status: "open",
             comments_count: 3,
             files_changed: 8
           }
         ],
         recent_commits: [
           {
             sha: "e4f5g6h",
             message: "Update color palette for dark mode",
             author: "carol",
             date: (current_time - (1 * 24 * 60 * 60)).iso8601
           }
         ]
       }
     ]

     prompt_text = "Generate a weekly development activity report for the period since #{one_week_ago}. Include key metrics and highlights from this data: #{repos_info.to_json}"
     summary = bedrock_invoke(prompt_text)
     { statusCode: 200, body: JSON.generate({ weekly_report: summary }) }
   end
   ```

2. **Test**:
   ```bash
   ruby -e 'require "./gh_jira_report"; puts gh_jira_report({}, {})'
   ```

---

## **Step 8: Cost Analysis With Mocked Cost Explorer**

**Objective:** Provide a real cost analysis AI flow using fake cost data.

1. **Create `cost_analysis.rb`**:

   ```ruby
   require "json"
   require_relative "./main"

   def cost_analysis_handler(event:, context:)
     # More detailed mock cost forecast
     mock_forecast = {
       "TotalCost" => {
         "Amount" => "250.75",
         "Unit" => "USD"
       },
       "Services" => [
         {
           "ServiceName" => "Amazon EC2",
           "Cost" => "100.25",
           "Usage" => "120 hours"
         },
         {
           "ServiceName" => "Amazon S3",
           "Cost" => "50.00",
           "Usage" => "200 GB-month"
         },
         {
           "ServiceName" => "Amazon Bedrock",
           "Cost" => "25.00",
           "Usage" => "LLM tokens usage"
         },
         {
           "ServiceName" => "Amazon RDS",
           "Cost" => "75.50",
           "Usage" => "db.t3.medium instance hours"
         }
       ],
       "TimePeriod" => {
         "Start" => "2025-01-08",
         "End" => "2025-01-15"
       }
     }

     prompt_text = "We have a cost forecast: #{mock_forecast.to_json}. Suggest ways to reduce AWS costs."
     result = bedrock_invoke(prompt_text)

     { statusCode: 200, body: JSON.generate({ cost_suggestions: result }) }
   end
   ```

2. **Test**:
   ```bash
   ruby -e 'require "./cost_analysis"; puts cost_analysis_handler({}, {})'
   ```
3. The AI output lists possible cost optimisations. All real calls to Cost Explorer are omitted.

---

## **Step 9: Iterate and Scale (Performance & Load Testing)**

**Objective:** Ensure your real Bedrock calls can handle concurrency. You do not spin up real AWS infra, but you do measure usage.

1. **Load Testing Locally**:

   ```bash
   for i in {1..20}; do
     ruby -e 'require "./resource_checker"; resource_checker({"queryStringParameters"=>{"q"=>"ec2"}}, {})'
   done
   ```

   Each iteration calls Bedrock for real.

2. **Concurrent Execution**:

   - If you deploy these as Lambda functions, set `ReservedConcurrentExecutions` to avoid accidental large-scale usage.

3. **Observability**:
   - Monitor how many times you call `bedrock_invoke`. Each call incurs cost.
   - Optionally log time or tokens used.

---

## **Step 10: Advanced Integrations (CI/CD Logs, Multi-Modal, Etc.)**

**Objective:** Demonstrate optional expansions, with only the final summary passing real data to Bedrock.

1. **`advanced_features.rb`** (CI/CD logs mock):

   ```ruby
   require "json"
   require_relative "./main"

   def ci_cd_logs_handler(event:, context:)
     # Fake logs
     logs = "Build #123 - 20 tests, 2 failures."
     prompt = "Summarize these CI/CD logs: #{logs}"
     result = bedrock_invoke(prompt)
     { statusCode: 200, body: JSON.generate({ ci_cd_summary: result }) }
   end
   ```

2. **Multi-Modal** (mocking an OCR step):
   ```ruby
   def image_analysis_handler(event:, context:)
     # Suppose you extracted text from an image
     extracted_text = "Mock image text: Diagram with 3 microservices."
     prompt = "We extracted text from an image: #{extracted_text}. Summarise the diagram."
     summary = bedrock_invoke(prompt)
     { statusCode: 200, body: JSON.generate({ image_summary: summary }) }
   end
   ```
3. These expansions confirm you can pass any mock data to Bedrock for real AI interpretation.

---

## **Extended Notes on Testing, Observability, Error Handling, and More**

Below are details you can incorporate into any or all steps, refining your workshop:

1. **Testing**

   - Use Minitest or RSpec for unit tests.
   - You can mock `bedrock_invoke` if you want purely local tests without costs, though final runs use real Bedrock.

2. **Observability**

   - Log each `bedrock_invoke` call with timestamp and prompt size.
   - If deployed on AWS Lambda, enable CloudWatch logs. Consider adding metrics for prompt length or call count.

3. **Error Handling**

   - Handle `Aws::Bedrock::Errors::ServiceError` and optionally retry on transient issues.

4. **Prompt Engineering**

   - If responses are odd, refine prompts (e.g., “You are an AWS AI agent. Summarise in bullet points.”).
   - Consider different Bedrock models based on performance or cost needs.

5. **Security**

   - Use `secure_bedrock_invoke` for content filtering.
   - Limit IAM to only `bedrock:InvokeModel`.

6. **Cost**
   - Calls to Bedrock are not free. Keep an eye on usage.
   - Large prompts can lead to high token consumption.

### **Prompt Engineering Best Practices for Bedrock**

1. **Model-Specific Formatting Requirements**

   - Some Bedrock models might want a “system prompt” or specific roles.
   - Check if you need to use roles like `system`, `assistant`, or `user`.

2. **Token Limit Considerations**

   - Stay within each model’s max tokens. Summarise inputs if they grow too large.

3. **Temperature / Sampling Parameters**

   - Adjust `temperature` for creativity vs. determinism.
   - Example:
     ```ruby
     resp = client.invoke_model(
       model_id: model_id,
       body: {
         prompt: prompt,
         maxTokens: 100,
         temperature: 0.7
       }
     )
     ```

4. **Example Responses**

   - A typical output:
     ```json
     {
       "generatedText": "Summarised EC2 data..."
     }
     ```

5. **Prompt Iteration & Testing**
   - Keep refining prompts. Use a test harness with typical user queries.

### **Troubleshooting Common Bedrock Integration Issues**

1. **Missing Permissions**: Ensure `bedrock:InvokeModel` is allowed.
2. **Incorrect Region**: Check Bedrock availability in your AWS Region.
3. **Model ID Not Found**: Verify your `model_id`.
4. **Prompt Too Large**: If truncated, shorten the input.
5. **Service Quotas / Throttling**: Watch for `429` or `AccessDenied`.
6. **Unexpected Response Formats**: Some models return metadata.
7. **Rate Exceeded**: Implement backoff or rate limiting if you see `429` errors.

---

## **Full Mandatory Summary**

You have completed **ten** steps, none of which is optional:

1. **(Step 1) Real Bedrock Invocation**: Verified you can call `bedrock:InvokeModel`.
2. **(Step 2) Mock All AWS**: All non-Bedrock AWS calls are mocked.
3. **(Step 3) Chatbot With Mock EC2**: Summarise fake instance data with real AI output.
4. **(Step 4) RAG With Mock Docs**: Combine doc text with user queries, feed it to Bedrock.
5. **(Step 5) AI-Driven Alerts**: Turn alarm data into AI-generated explanations.
6. **(Step 6) Security & Guardrails**: Limit IAM to bedrock:InvokeModel and filter outputs.
7. **(Step 7) GitHub/Jira Weekly Report**: Summarise dev activity from mock data.
8. **(Step 8) Cost Analysis**: Provide cost insights using fake data, real AI suggestions.
9. **(Step 9) Iterate & Scale**: Test concurrency and measure real Bedrock usage.
10. **(Step 10) Advanced Integrations**: Expand with CI/CD logs, multi-modal, etc.

Each file you created (`main.rb`, `resource_checker.rb`, `doc_chat_handler.rb`, `usage_agent.rb`, `gh_jira_report.rb`, `cost_analysis.rb`, `advanced_features.rb`) is part of the final solution. This end-to-end approach demonstrates how to integrate a real LLM service (Bedrock) without configuring real AWS resources you already know.

---

## **Final Checks and Next Steps**

1. **Clean Up**

   - If anything was deployed, tear it down to avoid costs (e.g. Lambda, Docker images).
   - Retain your code for future reference.

2. **Refine Prompts**

   - Modify text for better AI responses or lower token usage.

3. **Cost**

   - Monitor your Bedrock usage. Concurrency can increase costs quickly.
   - Try different models to see performance differences.

4. **Transition to Real AWS**

   - Replace mock calls with actual AWS SDK calls for EC2, CloudWatch, etc.
   - Ensure proper IAM permissions and budget alerts.

5. **Expand**
   - Add logging, X-Ray, or advanced best practices for production.
   - Integrate real GitHub/Jira tokens for genuine data if desired.
