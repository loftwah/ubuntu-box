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
  "AWS_ACCESS_KEY_ID": "AKIA...",
  "STRIPE_API_KEY": "sk_test_...",
  "SMTP_PASSWORD": "your-smtp-password",
  "JWT_SECRET": "your-jwt-secret"
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

### 5. Using Secrets in Your Application

Once the secrets are loaded into the environment variables, you can access them throughout your application. Here are some common patterns for using secrets:

#### Configuration Objects

Create configuration objects to encapsulate related secrets:

```ruby
# config/initializers/stripe.rb
Stripe.api_key = ENV.fetch('STRIPE_API_KEY')

# config/initializers/aws.rb
Aws.config.update({
  credentials: Aws::Credentials.new(
    ENV.fetch('AWS_ACCESS_KEY_ID'),
    ENV.fetch('AWS_SECRET_ACCESS_KEY')
  ),
  region: ENV.fetch('AWS_REGION', 'us-east-1')
})

# config/initializers/smtp_settings.rb
Rails.application.config.action_mailer.smtp_settings = {
  address: ENV.fetch('SMTP_SERVER', 'smtp.gmail.com'),
  port: ENV.fetch('SMTP_PORT', 587),
  user_name: ENV.fetch('SMTP_USERNAME'),
  password: ENV.fetch('SMTP_PASSWORD'),
  authentication: :plain,
  enable_starttls_auto: true
}
```

#### Service Classes

Create service classes that use secrets for external integrations:

```ruby
# app/services/payment_processor.rb
class PaymentProcessor
  def initialize
    @api_key = ENV.fetch('STRIPE_API_KEY')
    @webhook_secret = ENV.fetch('STRIPE_WEBHOOK_SECRET')
  end

  def process_payment(amount, token)
    Stripe::Charge.create({
      amount: amount,
      currency: 'usd',
      source: token,
      api_key: @api_key
    })
  end

  def verify_webhook(payload, signature)
    Stripe::Webhook.construct_event(
      payload, signature, @webhook_secret
    )
  end
end

# app/services/email_service.rb
class EmailService
  def initialize
    @api_key = ENV.fetch('SENDGRID_API_KEY')
    @from_email = ENV.fetch('SYSTEM_EMAIL_ADDRESS')
  end

  def send_welcome_email(user)
    client = SendGrid::Client.new(api_key: @api_key)
    # ... email sending logic
  end
end
```

#### Models

Use secrets in models when needed (though prefer service classes for external integrations):

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include JWT::Auth

  JWT_SECRET = ENV.fetch('JWT_SECRET')

  def generate_auth_token
    JWT.encode(
      { user_id: id, exp: 24.hours.from_now.to_i },
      JWT_SECRET,
      'HS256'
    )
  end

  def self.from_auth_token(token)
    decoded = JWT.decode(token, JWT_SECRET, true, algorithm: 'HS256')
    User.find(decoded.first['user_id'])
  rescue JWT::DecodeError
    nil
  end
end
```

### 6. AWS Deployment Setup

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

### 7. Testing Support

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

RSpec.describe User do
  describe "#generate_auth_token" do
    it "generates a valid JWT token" do
      with_secrets("JWT_SECRET" => "test_secret") do
        user = create(:user)
        token = user.generate_auth_token
        decoded_user = User.from_auth_token(token)
        expect(decoded_user).to eq(user)
      end
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

Missing Environment Variables:

- Check if SecretsManager loaded successfully during boot
- Verify the secret exists in 1Password
- Make sure you're using `ENV.fetch` to catch missing variables early
