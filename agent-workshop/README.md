# Bedrock AI Ops Assistant

A Ruby-based toolkit for interacting with AWS Bedrock, supporting both Claude and Nova models with a unified interface.

## Key Features

- 🤖 Model-agnostic invocation layer (supports Claude and Nova)
- 🔄 Adapters for different model formats
- 🛡️ Built-in error handling and retries
- 🔍 Mock AWS service integrations for development
- 📊 Example AI Ops use cases (cost analysis, security review, etc.)

## Quick Start

```bash
# Clone the repository
git clone https://your-repo/bedrock-ai-ops
cd bedrock-ai-ops

# Install dependencies
bundle install

# Set up your environment
cp .env.example .env
# Edit .env with your AWS credentials and settings
```

Edit `.env`:

```bash
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=your_account_id
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
BEDROCK_MODEL_TYPE=claude  # or nova
```

## Basic Usage

```ruby
require_relative 'app/main'

# Use default model (Claude)
result = bedrock_invoke("What is AWS Bedrock?")
puts result

# Use specific model
result = bedrock_invoke("What is AWS Bedrock?", model_type: :nova)
puts result

# With model-specific options
result = bedrock_invoke(
  "What is AWS Bedrock?",
  model_type: :nova,
  system_prompt: "You are an AWS expert",
  temperature: 0.7
)
puts result
```

## Example Use Cases

Each use case has a dedicated handler with mock data for development:

```ruby
# EC2 Resource Analysis
ruby app/resource_checker.rb

# Security Analysis
ruby app/security_analyzer.rb

# Cost Analysis
ruby app/cost_analyzer.rb

# GitHub/Jira Report Generation
ruby app/gh_jira_report.rb
```

## Model Configuration

### Claude

```ruby
BedrockHelper.configure(
  default_model: :claude,
  model_config: {
    claude: {
      version: "bedrock-2023-05-31",
      max_tokens: 500
    }
  }
)
```

### Nova

```ruby
BedrockHelper.configure(
  default_model: :nova,
  model_config: {
    nova: {
      temperature: 0.7,
      top_p: 0.9,
      max_tokens: 500
    }
  }
)
```

## Error Handling

The toolkit includes built-in error handling for common issues:

- Rate limiting
- Token quota exceeded
- Network timeouts
- Invalid responses

Example with custom error handling:

```ruby
begin
  result = bedrock_invoke("Your prompt")
rescue BedrockHelper::RateLimitError => e
  puts "Rate limit hit: #{e.message}"
rescue BedrockHelper::TokenQuotaError => e
  puts "Token quota exceeded: #{e.message}"
end
```

## Development

See [workshop.md](workshop.md) for a detailed walkthrough of building AI Ops applications with this toolkit.
