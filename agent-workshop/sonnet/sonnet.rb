require "json"
require "aws-sdk-bedrockruntime"
require "dotenv"

Dotenv.load

def bedrock_invoke(prompt_text)
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

  # Parse the response
  parsed_response = JSON.parse(response.body.read)
  
  # Get the response text
  response_text = parsed_response["content"][0]["text"]
  puts response_text
  
  # Return the response text
  response_text
end

# Only run example if file is executed directly
if __FILE__ == $0
  puts bedrock_invoke("Tell me about Loftwah, a Senior DevOps Engineer at SchoolStatus who used to produce as Loftwah The Beatsmiff")
end