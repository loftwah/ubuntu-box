require_relative "./main"
require "json"

def resource_checker(event:, context:)
  query = (event.dig("queryStringParameters", "q") || "").downcase
  return { statusCode: 400, body: "Missing query" } if query.empty?

  # Mock EC2 data
  mock_ec2_data = {
    "Reservations" => [
      {
        "Instances" => [
          {
            "InstanceId" => "i-abc1234efgh",
            "InstanceType" => "t3.medium",
            "State" => { "Name" => "running" },
            "Tags" => [
              { "Key" => "Name", "Value" => "WebServer" },
              { "Key" => "Environment", "Value" => "Production" }
            ]
          }
        ]
      }
    ]
  }

  if query.include?("ec2")
    prompt_text = "You are an AWS expert. I will give you EC2 instance details, and you should explain what they mean.

    Here is the instance:
    - A #{mock_ec2_data['Reservations'][0]['Instances'][0]['InstanceType']} instance (ID: #{mock_ec2_data['Reservations'][0]['Instances'][0]['InstanceId']})
    - It is currently #{mock_ec2_data['Reservations'][0]['Instances'][0]['State']['Name']}
    - It's named '#{mock_ec2_data['Reservations'][0]['Instances'][0]['Tags'].find { |t| t['Key'] == 'Name' }['Value']}' 
    - Running in the #{mock_ec2_data['Reservations'][0]['Instances'][0]['Tags'].find { |t| t['Key'] == 'Environment' }['Value']} environment

    Please provide a natural, conversational summary explaining what this instance is and its current state. Include details about what a t3.medium is typically used for."
    
    summary = bedrock_invoke(prompt_text)
    { statusCode: 200, body: JSON.generate({ answer: summary }) }
  else
    { statusCode: 200, body: JSON.generate({ answer: "I only handle EC2 queries currently." }) }
  end
end

# Only run if file is executed directly
if __FILE__ == $0
  result = resource_checker(
    event: {"queryStringParameters" => {"q" => "show me ec2 instances"}},
    context: {}
  )
  puts result[:body]
end 