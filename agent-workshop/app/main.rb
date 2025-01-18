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
      inputText: prompt_text,
      textGenerationConfig: {
        maxTokenCount: 500,
        temperature: 0.1,
        topP: 0.9
      }
    }),
    model_id: ENV["BEDROCK_MODEL_ID"] || "amazon.titan-text-express-v1",
    content_type: "application/json",
    accept: "application/json"
  )

  JSON.parse(response.body.read)["results"][0]["outputText"]
end

# Only run example if file is executed directly
if __FILE__ == $0
  puts bedrock_invoke("Tell me about Loftwah, a Senior DevOps Engineer at SchoolStatus who used to produce as Loftwah The Beatsmiff")
end