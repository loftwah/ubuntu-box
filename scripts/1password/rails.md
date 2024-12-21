# Rails 1Password Integration Guide: A Practical Approach

## Introduction

This guide provides a complete walkthrough of integrating 1Password with Ruby and Rails applications using the 1Password CLI with service accounts. We've deliberately chosen this approach over 1Password Connect for several important reasons.

## Why CLI with Service Accounts?

Understanding why we're using the CLI with service accounts rather than 1Password Connect is crucial for your implementation decision. The CLI approach provides significant advantages in terms of simplicity, accessibility, and maintenance.

### Advantages of the CLI Approach

The CLI with service accounts offers several benefits that make it the preferred choice for most Rails applications:

1. Universal Accessibility

   - Works with all 1Password account types (Personal, Family, Teams, Business)
   - Doesn't require a paid Business or Family account like Connect does
   - Enables individual developers to use it in their personal projects

2. Simplified Architecture

   - No additional services to maintain
   - Direct communication with 1Password's servers
   - Fewer points of failure
   - Less operational overhead

3. Reduced Infrastructure Costs

   - No need to run and monitor Connect servers
   - No additional compute resources required
   - Lower operational complexity
   - Fewer components to secure and maintain

4. Better Development Experience
   - Developers can use their personal accounts for local development
   - Seamless integration with existing 1Password workflows
   - Familiar command-line interface
   - Easy debugging with direct CLI commands

### When to Consider Connect

While we recommend the CLI approach for most cases, there are specific situations where Connect might be necessary:

1. If you require real-time secret updates without application restarts
2. When you need centralized secret management across many applications
3. If your security policy requires an additional abstraction layer
4. When you need advanced audit logging beyond what the CLI provides

However, for the vast majority of Rails applications, these requirements are unnecessary complexity. The CLI approach with service accounts provides everything needed for secure secret management while keeping the system simple and maintainable.

## Core Concepts

### Authentication Methods

For development environments, developers use their personal 1Password accounts. This provides:

- Full access to development secrets
- Interactive authentication
- Familiar interface through the CLI
- Integration with the 1Password desktop app

For staging, production, and automated environments, we use service accounts. These provide:

- Non-interactive authentication
- Single token authentication
- Perfect for CI/CD and automated processes
- No need for additional infrastructure like Connect servers

### Secret Storage Structure

In 1Password, we store our secrets as secure notes where each note has two essential components:

1. The note's name (this is critical for retrieval)
2. The secrets themselves (stored as JSON in the note's content)

For example, a secure note would be structured like this:

Name: `env.myapp.production`

```ruby
# This is how we'll retrieve it in our code:
op item get "env.myapp.production" --field notesPlain
```

Content (stored in the note's `notesPlain` field):

```json
{
  "DATABASE_URL": "postgres://user:pass@host:5432/db",
  "REDIS_URL": "redis://localhost:6379/0",
  "AWS_ACCESS_KEY_ID": "AKIA..."
}
```

The naming convention `env.{application}.{environment}` is crucial because:

1. It's how we locate our secrets using the CLI
2. It provides a consistent pattern across environments
3. It makes automation and secret rotation reliable
4. It helps prevent accessing the wrong environment's secrets

For example, you might have these secure notes:

- `env.myapp.development` - Local development secrets
- `env.myapp.staging` - Staging environment secrets
- `env.myapp.production` - Production environment secrets
- `env.otherapp.production` - Another application's production secrets

When retrieving secrets, the name must match exactly:

```ruby
def fetch_secrets
  app_name = Rails.application.class.module_parent_name.downcase
  note_name = "env.#{app_name}.#{Rails.env}"  # This must match the secure note's name exactly

  result = `op item get "#{note_name}" --field notesPlain`.strip
  if result.empty?
    raise "Failed to fetch secrets: Could not find secure note named '#{note_name}'"
  end
  result
end
```

## Implementation Guide

### Secret Management Service

Instead of having separate managers for development and production, we can create a single, environment-aware secrets manager:

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
      note_title = "env.#{app_name}.#{Rails.env}"

      # The note title is crucial - it must match exactly
      result = `op item get "#{note_title}" --field notesPlain`.strip
      raise "Failed to fetch secrets for #{note_title}" if result.empty?
      result
    end
  end
end
```

Add this to your application configuration:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    # ... other configuration ...

    # Load secrets early in the boot process
    config.before_configuration do
      SecretsManager.load_secrets
    end
  end
end
```

This unified approach has several advantages:

- Single source of truth for secret management
- Consistent behavior across environments
- Environment-appropriate authentication
- Simpler maintenance and updates
- Clear logging appropriate to each environment

First, install the 1Password CLI:

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

Create a development secrets manager:

```ruby
# lib/development_secrets.rb
class DevelopmentSecrets
  class << self
    def load
      return unless Rails.env.development?
      ensure_cli_authenticated
      load_environment_secrets
    end

    private

    def ensure_cli_authenticated
      unless system('op user get --me > /dev/null 2>&1')
        puts "\n⚠️  Please sign in to 1Password CLI:"
        unless system('op signin')
          raise "Failed to authenticate with 1Password CLI"
        end
      end
    end

    def load_environment_secrets
      json_content = fetch_secrets
      secrets = JSON.parse(json_content)
      secrets.each { |key, value| ENV[key] = value.to_s }

      puts "✅ Development secrets loaded from 1Password"
    rescue JSON::ParserError => e
      puts "❌ Error parsing secrets: #{e.message}"
      raise
    end

    def fetch_secrets
      app_name = Rails.application.class.module_parent_name.downcase
      result = `op item get "env.#{app_name}.development" --field notesPlain`.strip

      raise "Failed to fetch secrets" if result.empty?
      result
    end
  end
end
```

Add this to your development configuration:

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.after_initialize do
    DevelopmentSecrets.load
  end
end
```

### 2. Production Environment Setup

Create a service account in 1Password:

1. Go to Settings → Service Accounts
2. Create new service account (e.g., "myapp-production")
3. Grant access only to necessary vaults
4. Save the token (starts with "eyJ")

Create a production secrets manager:

```ruby
# app/services/secrets_manager.rb
class SecretsManager
  class << self
    def load_secrets
      return if Rails.env.test? || Rails.env.development?

      ensure_service_account_configured
      load_environment_secrets
    end

    private

    def ensure_service_account_configured
      token = ENV['OP_SERVICE_ACCOUNT_TOKEN']
      raise "OP_SERVICE_ACCOUNT_TOKEN must be set" if token.blank?
    end

    def load_environment_secrets
      json_content = fetch_secrets
      secrets = JSON.parse(json_content)

      secrets.each { |key, value| ENV[key] = value.to_s }

      Rails.logger.info "Secrets loaded from 1Password"
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse secrets: #{e.message}"
      raise
    rescue StandardError => e
      Rails.logger.error "Failed to load secrets: #{e.message}"
      raise
    end

    def fetch_secrets
      app_name = Rails.application.class.module_parent_name.downcase
      env_name = Rails.env

      result = `op item get "env.#{app_name}.#{env_name}" --field notesPlain`.strip
      raise "Failed to fetch secrets" if result.empty?
      result
    end
  end
end
```

Add the initializer:

```ruby
# config/initializers/secrets.rb
Rails.application.config.after_initialize do
  SecretsManager.load_secrets unless Rails.env.test?
end
```

### 3. Secret Management

Create a secrets management system with automated rotation:

```ruby
# app/jobs/secret_rotation_job.rb
class SecretRotationJob
  include Sidekiq::Job

  # Configure retry behavior for robustness
  sidekiq_options retry: 3, backtrace: true

  # Schedule format examples:
  # every day at 3am: '0 3 * * *'
  # every Sunday at 2am: '0 2 * * 0'
  # every first of the month: '0 0 1 * *'
  recurrence { daily.hour_of_day(3) }  # Runs every day at 3 AM

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
    current_secrets = fetch_current_secrets

    # Generate and test new secret
    new_value = generate_new_secret(secret_key)
    test_new_secret(secret_key, new_value)

    # Update secrets atomically
    updated_secrets = current_secrets.merge(secret_key => new_value)
    store_secrets(updated_secrets)

    # Notify team and record rotation
    record_rotation(secret_key)
    notify_team_of_success(secret_key)
  end

  def fetch_current_secrets
    json_content = `op item get "env.#{app_name}.#{Rails.env}" --field notesPlain`.strip
    JSON.parse(json_content)
  end

  def store_secrets(secrets)
    command = %(op item edit "env.#{app_name}.#{Rails.env}" notesPlain='#{secrets.to_json}')
    raise "Failed to store secrets" unless system(command)
  end

  def scheduled_rotations
    # Define which secrets need regular rotation and their schedules
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
    # Implement secret testing logic
    # For example, try connecting to database with new credentials
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

  def self.record_rotation(key)
    create!(
      key: key,
      rotated_at: Time.current,
      success: true
    )
  end
end

# lib/tasks/secrets.rake
namespace :secrets do
  desc "Create or update environment secrets in 1Password"
  task :update, [:environment] => :environment do |t, args|
    env = args[:environment] || Rails.env

    unless system('op user get --me > /dev/null 2>&1')
      puts "Please sign in to 1Password CLI first:"
      system('op signin')
    end

    app_name = Rails.application.class.module_parent_name.downcase
    item_name = "env.#{app_name}.#{env}"

    puts "Enter secrets in JSON format (end with Ctrl+D):"
    json_content = STDIN.read

    # Validate JSON format
    JSON.parse(json_content)

    command = <<~SHELL
      op item edit "#{item_name}" notesPlain="#{json_content.gsub('"', '\"')}"
    SHELL

    if system(command)
      puts "✅ Secrets updated successfully"
    else
      puts "❌ Failed to update secrets"
      exit 1
    end
  end

  desc "Rotate specified secret"
  task :rotate, [:key] => :environment do |t, args|
    key = args[:key]
    raise "Must specify secret key to rotate" if key.blank?

    # Fetch current secrets
    json_content = `op item get "env.#{app_name}.#{env}" --field notesPlain`.strip
    secrets = JSON.parse(json_content)

    # Generate new secret value
    new_value = SecureRandom.hex(32)
    secrets[key] = new_value

    # Update in 1Password
    system(%(op item edit "env.#{app_name}.#{env}" notesPlain='#{secrets.to_json}'))

    puts "Secret #{key} rotated successfully"
    puts "New value: #{new_value}"
  end
end
```

### 4. Development Workflow

Daily developer workflow:

```bash
# Start of day
op signin  # Sign in to 1Password CLI
bin/rails server

# Creating new secrets
# 1. Create JSON file
cat > new_secrets.json << EOL
{
  "DATABASE_URL": "postgres://localhost/myapp_development",
  "REDIS_URL": "redis://localhost:6379/0"
}
EOL

# 2. Update in 1Password
bin/rails secrets:update[development] < new_secrets.json
rm new_secrets.json  # Clean up

# Rotating secrets
bin/rails secrets:rotate[STRIPE_API_KEY]
```

### 5. Deployment Setup

For Heroku:

```bash
# Set service account token
heroku config:set OP_SERVICE_ACCOUNT_TOKEN=eyJ...

# For review apps, set in app.json
{
  "env": {
    "OP_SERVICE_ACCOUNT_TOKEN": {
      "required": true
    }
  }
}
```

### 5. AWS Deployment Setup

First, let's set up the necessary AWS resources for securely storing our 1Password service account token. We'll use AWS Systems Manager Parameter Store for this purpose.

For EC2:

```hcl
# terraform/ssm.tf
# Create the parameter to store the 1Password token
resource "aws_ssm_parameter" "op_service_account_token" {
  name        = "/myapp/${var.environment}/OP_SERVICE_ACCOUNT_TOKEN"
  description = "1Password service account token for ${var.environment}"
  type        = "SecureString"
  value       = var.op_token  # Set this through a sensitive variable

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM role policy to allow EC2 to read the parameter
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

Then in your EC2 instances, you can fetch the token:

```bash
# In your EC2 user data or deployment script
export OP_SERVICE_ACCOUNT_TOKEN=$(aws ssm get-parameter \
    --name "/myapp/${environment}/OP_SERVICE_ACCOUNT_TOKEN" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text)
```

For ECS deployments, we need additional resources for the task execution:

```hcl
# terraform/ecs.tf
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "myapp-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task execution role for pulling secrets
resource "aws_iam_role" "ecs_execution_role" {
  name = "myapp-${var.environment}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
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

# Task definition using the parameter
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

# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/myapp-${var.environment}"
  retention_in_days = 30
}
```

For error alerting and monitoring, you might want to set up CloudWatch alarms:

```hcl
# terraform/monitoring.tf
# Alarm for failed secret rotations
resource "aws_cloudwatch_log_metric_filter" "secret_rotation_failures" {
  name           = "secret-rotation-failures"
  pattern        = "[timestamp, application=myapp, level=ERROR, message=Failed to rotate*]"
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = "SecretRotationFailures"
    namespace = "MyApp/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "secret_rotation_failures" {
  alarm_name          = "secret-rotation-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "SecretRotationFailures"
  namespace          = "MyApp/${var.environment}"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "Secret rotation failures detected"
  alarm_actions      = [aws_sns_topic.alerts.arn]
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "myapp-${var.environment}-alerts"
}
```

For Sidekiq workers handling secret rotation, you'll want to ensure they're in a separate ECS service:

```hcl
# terraform/sidekiq.tf
resource "aws_ecs_service" "sidekiq" {
  name            = "myapp-sidekiq-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.sidekiq.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.sidekiq.id]
  }
}

resource "aws_ecs_task_definition" "sidekiq" {
  family                   = "myapp-sidekiq-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "sidekiq"
      image = "${var.ecr_repository_url}:${var.image_tag}"
      command = ["bundle", "exec", "sidekiq"]

      secrets = [
        {
          name      = "OP_SERVICE_ACCOUNT_TOKEN"
          valueFrom = aws_ssm_parameter.op_service_account_token.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.sidekiq.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}
```

### 6. Testing Support

Add test helpers:

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
RSpec.describe "Secret-dependent code" do
  it "works with specific secrets" do
    with_secrets("API_KEY" => "test-key") do
      # Your test code here
    end
  end
end
```

## Best Practices

### Security

1. Environment Separation

   - Use separate vaults for development and production
   - Use different service accounts for staging and production
   - Never mix environment secrets

2. Access Control

   - Grant minimal vault access to service accounts
   - Regularly audit access permissions
   - Rotate service account tokens periodically

3. Secret Storage
   - Store related secrets together in one JSON object
   - Use clear, consistent naming patterns
   - Include metadata like rotation schedules

### Operations

1. Secret Rotation

   - Schedule regular rotation for critical secrets
   - Document rotation procedures
   - Test applications with rotated secrets
   - Coordinate rotation with deployments

2. Monitoring

   - Log secret load attempts
   - Monitor secret access patterns
   - Alert on authentication failures
   - Track service account usage

3. Emergency Procedures
   - Document emergency rotation steps
   - Maintain list of critical secrets
   - Have rollback procedures ready
   - Keep emergency contacts updated

## Troubleshooting

### Common Issues

1. Authentication Problems

   ```
   Error: failed to authenticate with 1Password Connect server
   ```

   - Check service account token is set
   - Verify token hasn't expired
   - Ensure token has correct permissions

2. Secret Loading Failures

   ```
   Error: Failed to fetch secrets
   ```

   - Check item exists in 1Password
   - Verify JSON format is correct
   - Ensure CLI is authenticated

3. Permission Issues
   ```
   Error: You don't have permission to access this item
   ```
   - Check vault access permissions
   - Verify service account configuration
   - Review vault assignments

## Conclusion

This approach to Rails secret management with 1Password provides:

- Simple, reliable secret storage
- Easy development workflow
- Secure production deployments
- Clear separation of environments
- Straightforward secret rotation
- No additional infrastructure

Remember that secrets are loaded at application boot time. While this means application restarts are needed for secret updates, it provides a simpler and more reliable architecture than real-time secret fetching.
