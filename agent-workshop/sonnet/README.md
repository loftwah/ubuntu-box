# Using `sonnet.rb` from Another Ruby Script

This document explains how to use the `bedrock_invoke` function from `sonnet.rb` in another Ruby script.

## How to Use `sonnet.rb` in Another Script

### 1. Include `sonnet.rb` in Your Script

To use the `bedrock_invoke` function from `sonnet.rb`, you need to require the `sonnet.rb` file in your script.

#### Example: `caller_script.rb`

```ruby
# Require the sonnet.rb file from the same directory
require_relative 'sonnet'

# Call the bedrock_invoke method with a custom prompt
response = bedrock_invoke("Tell me about Loftwah, a Senior DevOps Engineer at SchoolStatus who used to produce as Loftwah The Beatsmiff")

# Output the response text
puts response
```
