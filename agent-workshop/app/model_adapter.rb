require 'json'
require 'aws-sdk-bedrockruntime'

# Base adapter class for Bedrock models
class BedrockModelAdapter
  def initialize(client)
    @client = client
  end

  def invoke(prompt_text, options = {})
    response = @client.invoke_model(
      model_id: model_id,
      content_type: "application/json",
      accept: "application/json",
      body: JSON.dump(format_request(prompt_text, options))
    )
    
    parse_response(response)
  end

  protected

  def model_id
    raise NotImplementedError, "Subclasses must implement model_id"
  end

  def format_request(prompt_text, options)
    raise NotImplementedError, "Subclasses must implement format_request"
  end

  def parse_response(response)
    raise NotImplementedError, "Subclasses must implement parse_response"
  end
end

# Claude-specific adapter
class ClaudeAdapter < BedrockModelAdapter
  def model_id
    account_id = ENV["AWS_ACCOUNT_ID"] || "984601232468"
    region = ENV["AWS_REGION"] || "us-east-1"
    "arn:aws:bedrock:#{region}:#{account_id}:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0"
  end

  protected

  def format_request(prompt_text, options = {})
    {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: options[:max_tokens] || 300,
      messages: [
        {
          role: "user",
          content: prompt_text
        }
      ]
    }
  end

  def parse_response(response)
    parsed = JSON.parse(response.body.read)
    parsed["content"][0]["text"]
  end
end

# Nova-specific adapter
class NovaAdapter < BedrockModelAdapter
  def model_id
    "us.amazon.nova-lite-v1:0"
  end

  protected

  def format_request(prompt_text, options = {})
    {
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
          text: options[:system_prompt] || "You are a helpful AI assistant."
        }
      ],
      inferenceConfig: {
        temperature: options[:temperature] || 0.7,
        topP: options[:top_p] || 0.9,
        maxTokens: options[:max_tokens] || 300,
        stopSequences: options[:stop_sequences] || []
      }
    }
  end

  def parse_response(response)
    parsed = JSON.parse(response.body.read)
    parsed["output"]["message"]["content"].first["text"]
  end
end

# Factory for creating model adapters
class BedrockModelFactory
  def self.create(model_type, client)
    case model_type.to_sym
    when :claude
      ClaudeAdapter.new(client)
    when :nova
      NovaAdapter.new(client)
    else
      raise ArgumentError, "Unsupported model type: #{model_type}"
    end
  end
end