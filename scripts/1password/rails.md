# Rails 1Password Integration: A Practical Guide

## Introduction

This guide explains how to integrate 1Password with Rails applications using the CLI with service accounts. We deliberately avoid using 1Password Connect since it requires additional infrastructure and is only available for Business/Family accounts. Our approach works with all account types and provides a simpler, more maintainable solution.

## Core Concepts

### Authentication Methods

Our implementation uses two authentication methods depending on the environment:

Development environments use personal 1Password accounts:

- Interactive CLI authentication
- Integrates with the developer's existing 1Password workflow
- Full access to development secrets

Production and staging environments use service accounts:

- Single token authentication
- Non-interactive, perfect for automation
- Restricted access to specific vaults

### Secret Storage Structure

Each environment's secrets are stored in a 1Password secure note with:

1. A name that identifies the environment: `env.{application}.{environment}`
2. The secrets stored as JSON in the note's content

For example:

Name: `env.myapp.production`

Content:

```json
{
  "DATABASE_URL": "postgres://user:pass@host:5432/db",
  "REDIS_URL": "redis://localhost:6379/0",
  "AWS_ACCESS_KEY_ID": "AKIA..."
}
```

This structure provides:

- Atomic updates (all related secrets updated together)
- Easy environment variable loading
- Clear organization by environment
- Simple secret rotation

## Implementation

### 1. Installing 1Password CLI

First, install the CLI on your development and deployment machines:

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

### 2. Setting Up Service Accounts

Create a service account for your production environment:

1. Go to Settings → Service Accounts in 1Password
2. Create a new account (e.g., "myapp-production")
3. Grant access only to the necessary vaults
4. Save the token (it starts with "eyJ")

### 3. Implementing the Secrets Manager

Create a single, environment-aware secrets manager that handles both development and production:

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

Load the secrets early in your application's boot process:

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

### 4. Secret Rotation with Sidekiq

Implement automated secret rotation:

```ruby
# app/jobs/secret_rotation_job.rb
class SecretRotationJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  recurrence { daily.hour_of_day(3) }  # Runs at 3 AM daily

  def perform(secret_key = nil)
    return rotate_all_secrets if secret_key.nil?
    rotate_single_secret(secret_key)
  end

  private

  def rotate_all_secrets
    scheduled_rotations.each do |secret_key|
      rotate_single_secret(secret_key)
    rescue => e
      Rails.logger.error "Failed to rotate #{secret_key}: #{e.message}"
      notify_team_of_failure(secret_key, e)
    end
  end

  def rotate_single_secret(secret_key)
    Rails.logger.info "Starting rotation for #{secret_key}"

    # Fetch current secrets
    json_content = fetch_current_secrets
    current_secrets = JSON.parse(json_content)

    # Generate and test new secret
    new_value = generate_new_secret(secret_key)
    test_new_secret(secret_key, new_value)

    # Update atomically
    updated_secrets = current_secrets.merge(secret_key => new_value)
    store_updated_secrets(updated_secrets)

    record_rotation(secret_key)
    notify_team_of_success(secret_key)
  end

  def fetch_current_secrets
    `op item get "env.#{app_name}.#{Rails.env}" --field notesPlain`.strip
  end

  def store_updated_secrets(secrets)
    command = %(op item edit "env.#{app_name}.#{Rails.env}" notesPlain='#{secrets.to_json}')
    raise "Failed to store secrets" unless system(command)
  end

  def scheduled_rotations
    {
      'DATABASE_PASSWORD' => 90.days,
      'API_KEY' => 30.days,
      'JWT_SECRET' => 60.days
    }.select do |key, interval|
      last_rotation = SecretRotationLog.where(key: key).last
      last_rotation.nil? || last_rotation.created_at < interval.ago
    end.keys
  end

  def generate_new_secret(key)
    case key
    when 'DATABASE_PASSWORD'
      SecureRandom.hex(32)
    when 'API_KEY'
      "sk_#{SecureRandom.hex(24)}"
    else
      SecureRandom.hex(32)
    end
  end

  def test_new_secret(key, value)
    case key
    when 'DATABASE_PASSWORD'
      test_database_connection(value)
    when 'API_KEY'
      test_api_connection(value)
    end
  end
end

# app/models/secret_rotation_log.rb
class SecretRotationLog < ApplicationRecord
  validates :key, presence: true
end
```

### 5. AWS Integration

Store the service account token securely in SSM Parameter Store:

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

# Allow EC2 to read the parameter
resource "aws_iam_role_policy" "ec2_ssm" {
  name = "ec2-ssm-parameter-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.op_service_account_token.arn
        ]
      }
    ]
  })
}
```

For ECS tasks:

```hcl
# terraform/ecs.tf
resource "aws_ecs_task_definition" "app" {
  family                   = "myapp-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "myapp"
      image = "${var.ecr_repository_url}:${var.image_tag}"

      secrets = [
        {
          name      = "OP_SERVICE_ACCOUNT_TOKEN"
          valueFrom = aws_ssm_parameter.op_service_account_token.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/myapp-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Allow task execution role to read the parameter
resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name = "parameter-store-access"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
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

### 6. Testing Strategy

Our secrets manager intentionally skips loading secrets in the test environment. This is a deliberate design choice that makes our tests more reliable and maintainable. Instead of loading real secrets from 1Password, we use a mocking approach that gives us complete control over our test environment.

When we look at our `SecretsManager`, the first line sets this up:

```ruby
def load_secrets
  return if Rails.env.test?  # Skip loading from 1Password in tests
  # ... rest of the implementation
end
```

This design lets us explicitly control what secrets are available during our tests. To support this, we implement a testing helper:

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

This approach provides several important benefits for testing:

First, it makes our tests isolated and reliable. Each test runs in a clean environment without depending on external services or the state of your 1Password vault. For example:

```ruby
RSpec.describe PaymentProcessor do
  it "processes payments with the correct API key" do
    with_secrets("STRIPE_API_KEY" => "test_key_123") do
      processor = PaymentProcessor.new
      expect(processor).to be_configured
    end
  end

  it "raises an error when API key is missing" do
    with_secrets({}) do  # Explicitly testing with no secrets
      expect {
        PaymentProcessor.new
      }.to raise_error(MissingAPIKeyError)
    end
  end
end
```

Second, it makes our tests deterministic and controllable. We can test various scenarios by providing different combinations of secrets:

```ruby
RSpec.describe AWSService do
  it "handles incomplete credentials properly" do
    # Test with partial credentials
    with_secrets(
      "AWS_ACCESS_KEY_ID" => "test_key",
      # Deliberately omitting AWS_SECRET_ACCESS_KEY
    ) do
      expect {
        AWSService.new
      }.to raise_error(IncompleteCredentialsError)
    end
  end

  it "works with complete credentials" do
    # Test with all required credentials
    with_secrets(
      "AWS_ACCESS_KEY_ID" => "test_key",
      "AWS_SECRET_ACCESS_KEY" => "test_secret"
    ) do
      expect(AWSService.new).to be_properly_configured
    end
  end
end
```

This testing strategy aligns with Rails testing best practices by:

- Keeping tests fast (no external service calls)
- Making tests reliable (no external dependencies)
- Allowing thorough testing of error conditions
- Maintaining clear test intentions
- Supporting parallel test execution

## Best Practices

### Security

- Use separate vaults per environment
- Grant minimal vault access to service accounts
- Rotate secrets and service account tokens regularly
- Never share development and production secrets

### Operations

- Monitor secret access in logs
- Set up alerts for rotation failures
- Document emergency procedures
- Maintain clear rotation schedules

## Troubleshooting

Common issues and solutions:

Authentication Problems:

```
Error: Failed to authenticate
```

- Check service account token is set
- Verify token permissions
- Ensure CLI is installed correctly

Secret Loading Failures:

```
Error: Failed to fetch secrets
```

- Verify note name matches expected format
- Check JSON is valid
- Confirm CLI authentication status

## Conclusion

This implementation provides:

- Simple secret management without extra services
- Clear separation between environments
- Easy secret rotation
- Secure deployment options
- Good developer experience

While secrets require an application restart to update, this tradeoff brings significant benefits in simplicity and reliability compared to real-time secret fetching or running additional infrastructure like Connect.
