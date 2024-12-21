# Rails 1Password Integration: The Essential Guide

This guide explains how to use 1Password to manage environment variables in Rails applications. We use the 1Password CLI instead of Connect because it works with all account types and doesn't require additional infrastructure.

## How It Works

We store environment variables as JSON in 1Password secure notes. Each environment (development, staging, production) has its own note. Developers use their personal 1Password accounts for development, while production uses a service account.

## Setup Steps

### 1. Install 1Password CLI

```bash
# macOS
brew install 1password-cli

# Ubuntu/Debian
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
sudo tee /etc/apt/sources.list.d/1password.list && \
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ && \
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol && \
sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 && \
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg && \
sudo apt update && sudo apt install 1password-cli
```

### 2. Create 1Password Secure Notes

Create a secure note for each environment with this structure:

Name: `env.{application}.{environment}`  
Example: `env.myapp.production`

Content (stored in the note's `notesPlain` field):

```json
{
  "DATABASE_URL": "postgres://user:pass@host:5432/db",
  "REDIS_URL": "redis://localhost:6379/0",
  "AWS_ACCESS_KEY_ID": "AKIA..."
}
```

### 3. Create Service Account

For production/staging environments:

1. Go to Settings → Service Accounts
2. Create a new account (e.g., "myapp-production")
3. Grant access to only the necessary vaults
4. Save the token (starts with "eyJ")

### 4. Implement Secrets Manager

```ruby
# app/services/secrets_manager.rb
class SecretsManager
  class << self
    def load_secrets
      return if Rails.env.test?  # Skip for test environment

      ensure_authentication
      load_environment_secrets
    end

    private

    def ensure_authentication
      if Rails.env.development?
        unless system('op user get --me > /dev/null 2>&1')
          puts "\n⚠️  Please sign in to 1Password CLI:"
          raise "Failed to authenticate" unless system('op signin')
        end
      else
        # Production-like environments use service account
        raise "OP_SERVICE_ACCOUNT_TOKEN must be set" if ENV['OP_SERVICE_ACCOUNT_TOKEN'].blank?
      end
    end

    def load_environment_secrets
      json_content = fetch_secrets
      secrets = JSON.parse(json_content)

      secrets.each { |key, value| ENV[key] = value.to_s }

      message = "✅ Secrets loaded from 1Password for #{Rails.env}"
      Rails.env.development? ? puts(message) : Rails.logger.info(message)
    rescue JSON::ParserError => e
      error = "Failed to parse secrets: #{e.message}"
      Rails.env.development? ? puts(error) : Rails.logger.error(error)
      raise
    end

    def fetch_secrets
      app_name = Rails.application.class.module_parent_name.downcase
      note_name = "env.#{app_name}.#{Rails.env}"

      result = `op item get "#{note_name}" --field notesPlain`.strip
      raise "Failed to fetch secrets: Could not find secure note named '#{note_name}'" if result.empty?
      result
    end
  end
end
```

Add to your application configuration:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    # Load secrets before other configuration
    config.before_configuration do
      SecretsManager.load_secrets
    end
  end
end
```

### 5. AWS Deployment Setup

Store the service account token in SSM Parameter Store:

```hcl
# terraform/ssm.tf
resource "aws_ssm_parameter" "op_service_account_token" {
  name        = "/myapp/${var.environment}/OP_SERVICE_ACCOUNT_TOKEN"
  description = "1Password service account token for ${var.environment}"
  type        = "SecureString"
  value       = var.op_token

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Allow EC2/ECS to read the parameter
resource "aws_iam_role_policy" "ssm_access" {
  name = "ssm-parameter-access"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "kms:Decrypt"
        ]
        Resource = [
          aws_ssm_parameter.op_service_account_token.arn,
          data.aws_kms_alias.ssm.target_key_arn
        ]
      }
    ]
  })
}
```

### 6. Testing Support

Add test helper for mocking secrets:

```ruby
# spec/support/secrets_helper.rb
module SecretsHelper
  def with_secrets(secrets)
    original_env = ENV.to_hash
    secrets.each { |key, value| ENV[key] = value }
    yield
  ensure
    ENV.clear
    original_env.each { |key, value| ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include SecretsHelper
end
```

Use in tests:

```ruby
RSpec.describe PaymentProcessor do
  it "processes payments" do
    with_secrets("STRIPE_API_KEY" => "test_key") do
      expect(PaymentProcessor.new).to be_configured
    end
  end
end
```

## Day-to-Day Usage

Development workflow:

```bash
# Start of day
op signin
rails server

# View current secrets
op item get env.myapp.development --field notesPlain

# Update secrets
op item edit env.myapp.development notesPlain="$(cat new_env.json)"
```

## Troubleshooting

Common issues:

Authentication Failed:

- For development: Run `op signin`
- For production: Check `OP_SERVICE_ACCOUNT_TOKEN` is set

Can't Find Secrets:

- Check note name matches `env.{app}.{environment}`
- Verify JSON format is valid
- Ensure you have access to the vault
