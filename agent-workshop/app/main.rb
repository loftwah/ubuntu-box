require "json"
require "dotenv"
require_relative "./bedrock_helper"

Dotenv.load

# Configure BedrockHelper once at startup
BedrockHelper.configure(
  region: ENV["AWS_REGION"] || "us-east-1",
  credentials: Aws::Credentials.new(
    ENV["AWS_ACCESS_KEY_ID"],
    ENV["AWS_SECRET_ACCESS_KEY"]
  )
)

def bedrock_invoke(prompt_text, options = {})
  BedrockHelper.invoke(prompt_text, options)
end

# Example usage when run directly
if __FILE__ == $0
  begin
    # Test with Claude
    puts "Testing Claude:"
    puts bedrock_invoke("Tell me a short joke", { model_type: :claude })
    
    # Test with Nova
    puts "\nTesting Nova:"
    puts bedrock_invoke("Tell me a short joke", { 
      model_type: :nova,
      system_prompt: "You are a humorous AI assistant"
    })
  rescue => e
    puts "Error occurred: #{e.class} - #{e.message}"
    exit 1
  end
end