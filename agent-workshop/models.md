# Complete AWS Bedrock Implementation Guide: Nova and Claude

## Introduction

AWS Bedrock provides access to multiple language models, each with their own specific implementation requirements. This guide focuses on two models:

- Amazon's Nova model (nova-lite-v1)
- Anthropic's Claude 3.5 (claude-3-5-sonnet)

Each model has distinct request/response structures and setup requirements. Understanding these differences is crucial for successful implementation.

## Initial AWS Setup

### Enabling Model Access

1. In AWS Console, navigate to Bedrock
2. Select "Model access" from the left sidebar
3. Enable these specific models:
   - Amazon Nova models
   - Anthropic Claude models
   - Wait for green checkmarks before proceeding

### Finding Available Models

Use AWS CLI to verify your model access:

```bash
aws bedrock list-foundation-models --region us-east-1
```

For Claude specifically, you need the inference profile:

```bash
aws bedrock list-inference-profiles --region us-east-1
```

### AWS Credentials Setup

Your `.env` file needs:

```
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key_here
AWS_SECRET_ACCESS_KEY=your_secret_here
```

Required gems in your Gemfile:

```ruby
gem "aws-sdk-bedrockruntime", "~> 1.32.0"
gem "json", "~> 2.6"
gem "dotenv", "~> 2.8"
```

## Nova Model Implementation

### Nova's Request Structure Explained

Nova uses a specific nested structure:

```ruby
{
  messages: [
    {
      role: "user",
      content: [              # Must be an array
        {
          text: prompt_text   # Actual prompt text goes here
        }
      ]
    }
  ],
  system: [                   # System message helps set context
    {
      text: "You are a helpful AI assistant."
    }
  ],
  inferenceConfig: {          # Control model behavior
    temperature: 0.7,         # Higher = more creative
    topP: 0.9,               # Nucleus sampling parameter
    maxTokens: 300,          # Maximum response length
    stopSequences: []        # Optional stop sequences
  }
}
```

### Nova's Response Structure

Nova returns responses in this structure:

```json
{
  "output": {
    "message": {
      "content": [
        {
          "text": "The actual response will be here"
        }
      ]
    }
  }
}
```

To access the response:

```ruby
response_text = parsed_response["output"]["message"]["content"].first["text"]
```

### Complete Nova Implementation

```ruby
require "json"
require "aws-sdk-bedrockruntime"
require "dotenv"

Dotenv.load

def nova_invoke(prompt_text)
  client = Aws::BedrockRuntime::Client.new(
    region: ENV["AWS_REGION"] || "us-east-1",
    credentials: Aws::Credentials.new(
      ENV["AWS_ACCESS_KEY_ID"],
      ENV["AWS_SECRET_ACCESS_KEY"]
    )
  )

  response = client.invoke_model(
    body: JSON.dump({
      messages: [
        {
          role: "user",
          content: [
            {
              text: prompt_text
            }
          ]
        }
      ],
      system: [
        {
          text: "You are a helpful AI assistant."
        }
      ],
      inferenceConfig: {
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 300,
        stopSequences: []
      }
    }),
    model_id: "us.amazon.nova-lite-v1:0",
    content_type: "application/json",
    accept: "application/json"
  )

  parsed_response = JSON.parse(response.body.read)
  response_text = parsed_response["output"]["message"]["content"].first["text"]
  puts response_text  # Optional but helpful for debugging
  response_text
end

# Test implementation
if __FILE__ == $0
  puts nova_invoke("Tell me about AWS Bedrock")
end
```

### Nova Configuration Parameters

- `temperature`: Controls randomness (0.0-1.0)

  - 0.7 is good for general use
  - Lower for more focused responses
  - Higher for more creative responses

- `topP`: Controls diversity (0.0-1.0)

  - 0.9 is a good default
  - Works with temperature to control response variety

- `maxTokens`: Maximum response length
  - 300 is good for medium responses
  - Increase for longer outputs
  - Decrease for shorter, more focused responses

## Claude Model Implementation

### Claude's Request Structure Explained

Claude uses a different, simpler structure:

```ruby
{
  anthropic_version: "bedrock-2023-05-31",  # Required version string
  max_tokens: 300,                          # Response length limit
  messages: [
    {
      role: "user",
      content: prompt_text                  # Direct string, no nesting
    }
  ]
}
```

### Claude's Response Structure

Claude returns responses in this structure:

```json
{
  "content": [
    {
      "text": "The response will be here"
    }
  ]
}
```

To access the response:

```ruby
response_text = parsed_response["content"][0]["text"]
```

### Complete Claude Implementation

```ruby
require "json"
require "aws-sdk-bedrockruntime"
require "dotenv"

Dotenv.load

def claude_invoke(prompt_text)
  client = Aws::BedrockRuntime::Client.new(
    region: ENV["AWS_REGION"] || "us-east-1",
    credentials: Aws::Credentials.new(
      ENV["AWS_ACCESS_KEY_ID"],
      ENV["AWS_SECRET_ACCESS_KEY"]
    )
  )

  response = client.invoke_model(
    model_id: "arn:aws:bedrock:us-east-1:984601232468:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0",
    content_type: "application/json",
    accept: "application/json",
    body: JSON.dump({
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 300,
      messages: [
        {
          role: "user",
          content: prompt_text
        }
      ]
    })
  )

  parsed_response = JSON.parse(response.body.read)
  response_text = parsed_response["content"][0]["text"]
  puts response_text  # Optional but helpful for debugging
  response_text
end

# Test implementation
if __FILE__ == $0
  puts claude_invoke("Tell me about AWS Bedrock")
end
```

### Claude Configuration Details

- `anthropic_version`: Must be exactly "bedrock-2023-05-31"
- `max_tokens`: Similar to Nova's maxTokens
- ARN format explained:
  ```
  arn:aws:bedrock:us-east-1:984601232468:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0
  ```
  - Region: us-east-1
  - Account ID: 984601232468
  - Model version: claude-3-5-sonnet-20241022-v2
  - Version suffix: 0

## Common Errors and Solutions

### Nova Common Issues

1. Wrong content structure:

   ```ruby
   # WRONG
   content: prompt_text

   # RIGHT
   content: [{ text: prompt_text }]
   ```

2. Missing system message:
   - Include the system message for better context
   - Can affect response quality

### Claude Common Issues

1. Wrong ARN:

   - Use `aws bedrock list-inference-profiles` to get correct ARN
   - Region must be us-east-1

2. Missing anthropic_version:

   - Must include exactly as shown
   - Will fail without it

3. Wrong content structure:
   - Don't nest content in array like Nova
   - Use direct string

## Response Handling

### Nova Response Example

```json
{
  "output": {
    "message": {
      "content": [
        {
          "text": "Here's a response from Nova..."
        }
      ]
    }
  }
}
```

### Claude Response Example

```json
{
  "content": [
    {
      "text": "Here's a response from Claude..."
    }
  ]
}
```

## When to Use Each Model

### Nova Advantages

- Simpler model ID
- More configuration options
- Built-in system message support

### Claude Advantages

- Generally more capable
- Simpler content structure
- Strong reasoning capabilities

## Testing Both Models

Create `test_models.rb`:

```ruby
require "json"
require "aws-sdk-bedrockruntime"
require "dotenv"

Dotenv.load

# [Paste Nova implementation here]
# [Paste Claude implementation here]

puts "Testing Nova:"
puts "=" * 50
puts nova_invoke("What's 2+2 and why?")

puts "\nTesting Claude:"
puts "=" * 50
puts claude_invoke("What's 2+2 and why?")
```

## AWS CLI Commands Reference

Check model access:

```bash
aws bedrock list-foundation-models --output table --region us-east-1
```

Get Claude inference profile:

```bash
aws bedrock list-inference-profiles --region us-east-1
```

Check access permissions:

```bash
aws bedrock get-foundation-model-access
```

## Final Notes

1. Always test both models with the same prompt to understand differences
2. Keep track of response structures - they're different for each model
3. Monitor token usage - it affects costs
4. Use proper error handling in production
5. Consider implementing retries for API failures

Remember: The key differences are in the:

- Request structure (nested vs. direct)
- Response paths (output.message vs. content)
- Configuration options
- Model identification (ID vs. ARN)
