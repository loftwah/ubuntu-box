# Bedrock AI Ops Assistant

A **Ruby-based toolkit** for interacting with **AWS Bedrock**. It supports multiple models (e.g. **Claude** and **Nova**) via a **unified interface**, and you can extend it to other models by creating new adapters.

This document explains:

1. How to **install** and **configure** the assistant.
2. **Where** to find each model’s **request structure** and how to parse its **response**.
3. How to **add new models** or **handle special features** like images.
4. **Troubleshooting** and **monitoring usage**.

---

## Table of Contents

1. [Overview](#overview)  
2. [Prerequisites](#prerequisites)  
3. [Installation and Setup](#installation-and-setup)  
4. [Environment Configuration](#environment-configuration)  
5. [Basic Usage](#basic-usage)  
6. [How to Discover a Model’s Required Request and Response Structures](#how-to-discover-a-models-required-request-and-response-structures)  
   - [1. AWS Documentation](#1-aws-documentation)  
   - [2. AWS CLI Calls](#2-aws-cli-calls)  
   - [3. Sample Requests in the Console](#3-sample-requests-in-the-console)  
   - [4. Trial and Error](#4-trial-and-error)  
   - [5. Learning from This Repository’s Adapters](#5-learning-from-this-repositorys-adapters)  
7. [Supported Models](#supported-models)  
   - [Claude](#claude)  
   - [Nova](#nova)  
   - [Request/Response Comparison](#requestresponse-comparison)  
8. [Adding New Models](#adding-new-models)  
   - [Adapter Class](#adapter-class)  
   - [Factory Configuration](#factory-configuration)  
   - [Parsing the Response](#parsing-the-response)  
9. [Working with Images (Multimodal)](#working-with-images-multimodal)  
10. [Configuration Reference](#configuration-reference)  
    - [Check Available Models](#check-available-models)  
    - [Token Limits](#token-limits)  
    - [Temperature Guide](#temperature-guide)  
    - [Common Configurations](#common-configurations)  
11. [Troubleshooting](#troubleshooting)  
    - [Token Quota Exceeded](#token-quota-exceeded)  
    - [Rate Limits](#rate-limits)  
    - [Monitor Usage](#monitor-usage)  

---

## 1. Overview

This **Bedrock AI Ops Assistant** provides a **unified Ruby interface** (`bedrock_invoke`) that calls AWS Bedrock for you. Bedrock hosts multiple LLMs (e.g. Claude or Nova), each with its own **JSON request format** and **response schema**. Our adapter classes **hide** these differences from you—unless you want to **add a new model** or **modify** an existing one.

**Key benefits**:
- **Simplicity**: One method, many models.
- **Flexibility**: Adjust temperature, max tokens, or system prompts in one place.
- **Extendability**: Add new models by writing a small adapter that defines how to **format requests** and **parse responses**.

---

## 2. Prerequisites

- **Ruby** 3.x preferred.
- **Bundler** for installing gems.
- **AWS credentials** with permission for `bedrock:InvokeModel`.
- Familiarity with **LLM parameters** (temperature, tokens, etc.).

---

## 3. Installation and Setup

1. **Clone** this repository or move these files into your own Ruby project.
2. Run:
   ```bash
   bundle install
   ```
3. Confirm gems like `aws-sdk-bedrockruntime` are present.

---

## 4. Environment Configuration

1. **Copy** the sample `.env`:
   ```bash
   cp .env.example .env
   ```
2. **Edit** `.env` to include your **AWS credentials** and a **default model**:
   ```bash
   AWS_REGION=us-east-1
   AWS_ACCOUNT_ID=123456789012
   AWS_ACCESS_KEY_ID=your_key
   AWS_SECRET_ACCESS_KEY=your_secret
   BEDROCK_MODEL_TYPE=claude  # or nova
   ```
3. **Keep** `.env` **secure**. Do not commit it to Git if it contains secrets.

---

## 5. Basic Usage

```ruby
require_relative 'app/main'

# Call the default model (from .env, e.g. claude)
answer = bedrock_invoke("Explain what AWS Bedrock is.")
puts answer

# Override the default model and add extra parameters
answer = bedrock_invoke("Explain what AWS Bedrock is.", {
  model_type: :nova,
  temperature: 0.7,
  max_tokens: 1024,
  system_prompt: "You are an AWS expert."
})
puts answer
```

**Parameters**:
- `:model_type` → `:claude` or `:nova`
- `:temperature` → 0.0 (very focused) to ~1.0 (more creative)
- `:max_tokens` → limit the maximum length
- `:system_prompt` (Nova only) → sets overall context or style

---

## 6. How to Discover a Model’s Required Request and Response Structures

Each **Bedrock model** can require a **unique** JSON schema. You need **two pieces** of information:

1. **How to format the request** (e.g. where to put the prompt, any special fields like `anthropic_version`, `messages`, or `system`).
2. **What the response JSON** looks like, so you can extract the final text.

When you add a new model, **here’s** how you find those details:

### 6.1 AWS Documentation
Look for official **AWS docs** describing the model. For example, if it’s `anthropic.claude-2`, there may be a reference page showing the exact JSON shape. Anthropic and Amazon models each have their own specification.

### 6.2 AWS CLI Calls
Use the AWS CLI to:
```bash
aws bedrock list-foundation-models --region us-east-1
aws bedrock get-foundation-model --model-id <the-model-id>
```
Sometimes, the `get-foundation-model` output or related doc pages link to a “Usage” or “Examples” section.

### 6.3 Sample Requests in the Console
The **AWS Bedrock console** often has a playground. You can send a sample prompt there. The console might show you the JSON or at least hints about required fields (like “maxTokenCount” or “inferenceConfig”).  

If the console **doesn’t** show direct JSON, sometimes you can open Developer Tools (in your browser) to see the **network request**. This can reveal the real structure it’s sending.

### 6.4 Trial and Error
- Try forming **a basic request** and see if you get an error.  
- The error might say something like **“Invalid field: expected ‘messages’ to be an array.”**  
- Adjust your request code to match the error’s hints.

### 6.5 Learning from This Repository’s Adapters
Check the existing **ClaudeAdapter** and **NovaAdapter** in `model_adapter.rb`. They each have:

- A `format_request` method returning the **exact** JSON structure required for that model.
- A `parse_response` method to handle the JSON returned.  

Use these as references for how requests and responses differ.  

**For instance**, Nova’s `format_request` includes:
```ruby
{
  messages: [
    { role: "user", content: [ { text: prompt_text } ] }
  ],
  system: [
    { text: options[:system_prompt] || "You are a helpful AI assistant." }
  ],
  inferenceConfig: { ... }
}
```
While Claude’s `format_request` includes:
```ruby
{
  anthropic_version: "bedrock-2023-05-31",
  max_tokens: options[:max_tokens] || 300,
  messages: [
    { role: "user", content: prompt_text }
  ]
}
```

And for **parsing**:
- Nova does `parsed_response["output"]["message"]["content"].first["text"]`.
- Claude does `parsed["content"][0]["text"]`.

---

## 7. Supported Models

### 7.1 Claude

In `ClaudeAdapter`, the request looks like this:

```ruby
{
  anthropic_version: "bedrock-2023-05-31",
  max_tokens: 300,
  messages: [
    {
      role: "user",
      content: "Your prompt text"
    }
  ]
}
```
**Claude’s response** typically arrives as:

```json
{
  "content": [
    {
      "text": "Here is Claude's response"
    }
  ]
}
```
Hence our adapter’s `parse_response` reads:
```ruby
parsed["content"][0]["text"]
```

### 7.2 Nova

In `NovaAdapter`, the request looks like:

```ruby
{
  messages: [
    {
      role: "user",
      content: [
        {
          text: "Your prompt text"
        }
      ]
    }
  ],
  system: [
    {
      text: "Optional system-level instructions"
    }
  ],
  inferenceConfig: {
    temperature: 0.7,
    topP: 0.9,
    maxTokens: 300,
    stopSequences: []
  }
}
```

**Nova’s response** typically is:
```json
{
  "output": {
    "message": {
      "content": [
        {
          "text": "Here is Nova's response"
        }
      ]
    }
  }
}
```

So our adapter’s `parse_response` does:
```ruby
parsed["output"]["message"]["content"].first["text"]
```

### Request/Response Comparison

|                | **Claude**                       | **Nova**                                   |
|----------------|----------------------------------|--------------------------------------------|
| **Request**    | - `anthropic_version`<br>- `messages` with `role` & `content`<br>- `max_tokens` | - `messages` array with nested `content`<br>- `system` array<br>- `inferenceConfig` (`temperature`, `maxTokens`, etc.) |
| **Response**   | JSON with `"content"[0]["text"]` | JSON with `"output"."message"."content"[0]["text"]` |
| **System Prompt** | Usually embedded in the prompt text directly (no separate field) | Provided via the `"system"` array (optional) |

---

## 8. Adding New Models

### 8.1 Adapter Class
Create a new file or add a new class in `model_adapter.rb`:
```ruby
class NewModelAdapter < BedrockModelAdapter
  def model_id
    # The ARN or ID for your new model, e.g. "arn:aws:bedrock:..."
    "arn:aws:bedrock:us-east-1:123456789012:foundation-model/your-cool-model"
  end

  protected

  def format_request(prompt_text, options = {})
    # Adjust to match what the model docs say. For example:
    {
      version: "2025-01-01",
      prompt: prompt_text,
      parameters: {
        temperature: options[:temperature] || 0.5,
        maxTokens: options[:max_tokens] || 512
      }
    }
  end

  def parse_response(response)
    # The API typically returns an HTTP body that you parse as JSON:
    parsed = JSON.parse(response.body.read)
    # Suppose your model returns { "generatedText": "some string" }
    parsed["generatedText"]  
  end
end
```
The **`format_request`** method is exactly **how** you send your prompt, shaped for that model’s needs. The **`parse_response`** method is how you **pull** the final text from the JSON.

### 8.2 Factory Configuration
In the same `model_adapter.rb` or wherever the factory lives:
```ruby
class BedrockModelFactory
  def self.create(model_type, client)
    case model_type.to_sym
    when :claude
      ClaudeAdapter.new(client)
    when :nova
      NovaAdapter.new(client)
    when :new_model
      NewModelAdapter.new(client)
    else
      raise ArgumentError, "Unsupported model type: #{model_type}"
    end
  end
end
```
Now you can do:
```ruby
bedrock_invoke("Test prompt", model_type: :new_model, max_tokens: 200)
```
### 8.3 Parsing the Response
**Where do I see the JSON structure?**  
- Check your new model’s docs.  
- Make a sample request with the **AWS CLI** or the **Bedrock console**.  
- If the response includes fields like `"answers"` or `"generatedText"`, that’s how you know which JSON key to parse in `parse_response`.

---

## 9. Working with Images (Multimodal)

Some models allow you to send **images** (in Base64 form) in the JSON. For instance, certain Claude versions might let you do:

```ruby
# Encode your image data
image_bytes = File.read("diagram.png")
encoded = Base64.strict_encode64(image_bytes)

# Provide it in the request, depending on model docs
response = bedrock_invoke("What does this image represent?", {
  model_type: :claude,
  image_base64: encoded  # if the model expects e.g. "image_base64" field
})
```
Again, the **key** is reading that model’s doc to see if it wants:
```json
{ "images": [ { "base64": "..."} ] }
```
or some other format. Then implement that logic in `format_request`.

---

## 10. Configuration Reference

### 10.1 Check Available Models
```bash
aws bedrock list-foundation-models --region us-east-1
aws bedrock list-inference-profiles --region us-east-1
```
You’ll see a list like `anthropic.claude-3.5` or `amazon.nova-lite-v2`, with ARNs or model IDs.

### 10.2 Token Limits
Each model has a **max token limit**. Exceed it and you get errors or truncated text. Check docs or do:

```bash
aws bedrock get-foundation-model --model-id anthropic.claude-3-sonnet-20240229-v1
```
Some output might show a token limit or mention “context length: 4096 tokens.”

### 10.3 Temperature Guide
```ruby
# Lower = more precise, less "creative"
bedrock_invoke("Say something about S3", temperature: 0.1)

# Higher = more expansive or inventive
bedrock_invoke("Generate creative story ideas", temperature: 1.0)
```

### 10.4 Common Configurations

**Production** (deterministic, safer):
```ruby
BedrockHelper.configure(
  default_model: :claude,
  model_config: {
    claude: {
      temperature: 0.1,
      max_tokens: 1000,
      top_p: 0.7
    }
  },
  max_retries: 3
)
```

**Development** (more varied):
```ruby
BedrockHelper.configure(
  default_model: :nova,
  model_config: {
    nova: {
      temperature: 0.8,
      max_tokens: 4000,
      top_p: 0.9
    }
  }
)
```

---

## 11. Troubleshooting

### 11.1 Token Quota Exceeded
If you see something like `TokenQuotaError`:
```ruby
# Try shorter responses
bedrock_invoke("Prompt", max_tokens: 300)
# Or reduce your input prompt size
```

### 11.2 Rate Limits
Too many calls in a short time can lead to `429` (Too Many Requests).  
Implement:
```ruby
BedrockHelper.configure(max_retries: 3, retry_delay: 2)
```
Or add your own throttling mechanism.

### 11.3 Monitor Usage
Check how often and how long you’re using the model:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Bedrock \
  --metric-name InvokeModelDuration \
  --dimensions Name=ModelId,Value=anthropic.claude-3-sonnet-20240229-v1 \
  --start-time 2024-01-19T00:00:00 \
  --end-time 2024-01-19T23:59:59 \
  --period 3600 \
  --statistics Sum
```
This helps avoid surprises in cost.

---

## Final Notes

- **Each model** has its **own** request/response structure. Reading the docs or observing a sample call is the fastest way to confirm how to form the JSON.
- **When** you want to add a model:
  1. Check its request schema (how to place the prompt).
  2. Check its response (how to parse the answer).
  3. Implement a new adapter class with `format_request` and `parse_response`.
  4. Add it to the **factory**.
- Keep an eye on **cost** and **token usage**—LLMs can be expensive at large scale.
