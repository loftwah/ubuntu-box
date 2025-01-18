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
    model_id: ENV["BEDROCK_MODEL_ID"] || "us.amazon.nova-lite-v1:0",
    content_type: "application/json",
    accept: "application/json"
  )

  # Parse the response
  parsed_response = JSON.parse(response.body.read)
  
  # Get the response text
  response_text = parsed_response["output"]["message"]["content"].first["text"]
  puts response_text
  
  # Return the response text
  response_text
end

# Only run example if file is executed directly
if __FILE__ == $0
  puts bedrock_invoke("Tell me about Loftwah, a Senior DevOps Engineer at SchoolStatus who used to produce as Loftwah The Beatsmiff")
end
