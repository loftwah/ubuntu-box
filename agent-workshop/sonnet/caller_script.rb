# Require the sonnet.rb file from the same directory
require_relative 'sonnet'

# Call the bedrock_invoke method with a custom prompt
response = bedrock_invoke("Tell me how to create a new Ruby application that starts with tailwind, postgres and gets me going with docker compose")

# Output the response text
puts response