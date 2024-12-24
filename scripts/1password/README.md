# 1Password Environment Management Scripts

[Terraform 1password provider](https://github.com/1Password/terraform-provider-onepassword)

Scripts to store and manage environment variables in 1Password, compatible with both bash scripts and Ruby applications.

## Prerequisites

- Install the [1Password CLI](https://developer.1password.com/docs/cli/get-started/) (`op`).
- Ensure `jq` is installed: `sudo apt install jq` (Linux) or `brew install jq` (Mac).
- For service account setup: Access to create and manage service accounts in your 1Password organization.

## Understanding 1Password Authentication

The 1Password CLI supports two distinct authentication methods: personal account authentication and service account authentication. Understanding the differences is crucial for choosing the right approach for your use case.

### Personal Account Authentication (Interactive CLI)

This is the traditional way of using the 1Password CLI, similar to how you log into the 1Password app. It requires interactive signin and regular reauthentication.

What you need:

```text
1. Account URL (e.g., my-team.1password.com)
2. Email address
3. Secret key (starts with A3-)
4. Master password
```

How it works:

```bash
# Initial signin - this will prompt you interactively
op signin my.1password.com email@example.com

# The CLI will ask for:
# - Your secret key (A3-...)
# - Your master password
# - If you use a different URL for work use that here

# The signin creates a temporary session token that expires after 30 minutes
# This is why you often see this command:
eval $(op signin)

# After signin, you can run commands:
op item get "my-secret"

# After 30 minutes, you'll need to signin again
```

### Service Account Authentication (Non-Interactive)

Service account authentication is designed for automation and scripts. It uses a single token and doesn't require interactive signin or periodic reauthentication.

What you need:

```text
1. Service account token only (starts with eyJ)
   - This single token replaces all the credentials needed for personal accounts
   - No email, password, secret key, or account URL needed
```

How it works:

```bash
# Set the token as an environment variable
export OP_SERVICE_ACCOUNT_TOKEN="eyJhbG..."

# That's it! You can now run commands directly:
op item get "my-secret"

# The token doesn't expire after 30 minutes like personal account sessions
```

### Comparing the Methods

Here's the same script written both ways to illustrate the difference:

```bash
# Using personal account authentication:
#!/bin/bash
# This will interrupt the script to prompt for credentials
eval $(op signin)
op item get "my-secret" --field password

# Using service account authentication:
#!/bin/bash
# No interruption - runs completely automated
export OP_SERVICE_ACCOUNT_TOKEN="eyJhbG..."
op item get "my-secret" --field password
```

The service account approach is better for:

- Automated scripts and deployments
- CI/CD pipelines
- Server applications
- Any scenario where you can't have human interaction

The personal account approach is better for:

- Local development
- Manual operations
- Testing and troubleshooting
- Any scenario where you want full account access

## Quick Start

> **Note**: Choose either CLI or service account authentication based on your use case. Service accounts are recommended for automated processes and deployments.

### 1. Service Account Setup

First, create a service account in 1Password:

1. Go to Settings → Service Accounts in your 1Password admin console
2. Create a new service account with a descriptive name (e.g., "myapp-env-loader")
3. Grant access to specific vaults where environment variables will be stored
4. Save the token securely - this is the only credential you'll need for the service account
   - The token will start with "eyJ" and is a long JWT string
   - Unlike personal accounts, you won't need email, password, secret key, or account URL
   - The token combines all necessary authentication information into a single credential

Service account tokens are designed for automated processes and have several advantages:

- Simpler authentication (single token vs multiple credentials)
- Can be easily rotated without affecting human users
- More restrictive permissions can be applied
- Activity can be audited separately from human users

### 2. Store your .env file

```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"
./store-env-to-op.sh -f .env -p myproject
```

This creates a secure note in 1Password with title `env.myproject.development` containing all your env vars as JSON:

```json
{
  "DATABASE_URL": "postgres://localhost:5432",
  "REDIS_URL": "redis://localhost:6379",
  "API_KEY": "secret123"
}
```

### 3. Retrieve your .env file

```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"
./retrieve-env-from-op.sh -p myproject -o .env
```

## Ruby Integration

The stored secrets are compatible with Ruby applications. Here are several approaches to integration:

### Basic Rails Integration

Create an initializer (`config/initializers/secrets_loader.rb`):

```ruby
class SecretsLoader
  class << self
    def load_secrets
      return unless should_load_secrets?

      ensure_service_account_token
      load_environment_secrets
    end

    private

    def should_load_secrets?
      # Customize this based on your needs
      Rails.env.development? || Rails.env.staging?
    end

    def ensure_service_account_token
      return if ENV['OP_SERVICE_ACCOUNT_TOKEN'].present?

      raise "OP_SERVICE_ACCOUNT_TOKEN must be set for secrets loading"
    end

    def load_environment_secrets
      json_content = fetch_secret(secret_name, 'notesPlain')
      secrets = JSON.parse(json_content)

      secrets.each { |key, value| ENV[key.to_s.upcase] = value }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse 1Password secrets: #{e.message}"
      raise
    rescue StandardError => e
      Rails.logger.error "Failed to load 1Password secrets: #{e.message}"
      raise
    end

    def secret_name
      "env.#{Rails.application.class.module_parent_name.downcase}.#{Rails.env}"
    end

    def fetch_secret(item, field)
      result = `op item get "#{item}" --field "#{field}"`.strip
      raise "Failed to fetch secret" if result.empty?
      result
    end
  end
end

# Load secrets during initialization
SecretsLoader.load_secrets if defined?(Rails)
```

### Advanced Integration with Credential Management

For more complex applications, you might want to create a dedicated secrets management service:

```ruby
# app/services/credentials_manager.rb
class CredentialsManager
  class SecretNotFoundError < StandardError; end
  class AuthenticationError < StandardError; end

  class << self
    def fetch_credentials
      new.fetch_credentials
    end
  end

  def fetch_credentials
    validate_configuration
    load_secrets_from_onepassword
  rescue StandardError => e
    handle_error(e)
  end

  private

  def validate_configuration
    return if ENV['OP_SERVICE_ACCOUNT_TOKEN'].present?

    raise AuthenticationError, 'Service account token not configured'
  end

  def load_secrets_from_onepassword
    json_content = fetch_secret(secret_name, 'notesPlain')
    parse_and_load_secrets(json_content)
  end

  def parse_and_load_secrets(json_content)
    secrets = JSON.parse(json_content)
    Rails.logger.info "Loaded #{secrets.keys.count} environment variables"

    secrets.each { |key, value| ENV[key.to_s.upcase] = value }
  end

  def secret_name
    @secret_name ||= begin
      app_name = Rails.application.class.module_parent_name.downcase
      environment = Rails.env
      "env.#{app_name}.#{environment}"
    end
  end

  def fetch_secret(item, field)
    result = `op item get "#{item}" --field "#{field}"`.strip

    if result.empty?
      raise SecretNotFoundError, "Secret '#{item}' not found"
    end

    result
  end

  def handle_error(error)
    case error
    when JSON::ParserError
      Rails.logger.error "Invalid JSON in 1Password secret: #{error.message}"
    when SecretNotFoundError
      Rails.logger.error "1Password secret not found: #{error.message}"
    when AuthenticationError
      Rails.logger.error "1Password authentication failed: #{error.message}"
    else
      Rails.logger.error "Unexpected error loading secrets: #{error.message}"
    end

    raise error
  end
end
```

### Environment-Specific Configuration

You can create environment-specific configurations in your Rails application:

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.after_initialize do
    CredentialsManager.fetch_credentials if ENV['LOAD_1PASSWORD_SECRETS']
  end
end

# config/environments/staging.rb
Rails.application.configure do
  config.after_initialize do
    CredentialsManager.fetch_credentials
  end
end
```

### Using with Docker

When using Docker, you'll need to pass the service account token to your container. Here's an example Docker Compose configuration:

```yaml
# docker-compose.yml
version: "3"
services:
  web:
    build: .
    environment:
      - OP_SERVICE_ACCOUNT_TOKEN=${OP_SERVICE_ACCOUNT_TOKEN}
    command: bash -c "bundle exec rails credentials:fetch && bundle exec rails s -p 3000 -b '0.0.0.0'"
```

### Testing Considerations

For your test environment, you might want to skip loading 1Password secrets. Add this to your test helper:

```ruby
# spec/spec_helper.rb or test/test_helper.rb
class SecretsLoader
  def self.load_secrets
    return if Rails.env.test?
    super
  end
end
```

## Security Best Practices

1. Never commit the service account token to version control
2. Use different service accounts for different environments
3. Limit service account access to only the necessary vaults
4. Rotate service account tokens periodically
5. Monitor service account usage through 1Password audit logs

## Deployment Considerations

### Heroku

For Heroku deployments, set the service account token as a config var:

```bash
heroku config:set OP_SERVICE_ACCOUNT_TOKEN=your-token-here
```

### Kubernetes

For Kubernetes deployments, store the service account token as a secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: onepassword-service-account
type: Opaque
data:
  token: <base64-encoded-token>
```

## Adding Scripts to Your PATH

To make the 1Password environment management scripts accessible from any directory, you can add them to your system's PATH.

### Steps to Add Scripts to PATH

1. **Move or Link the Scripts to a Dedicated Directory**  
   Choose a directory for custom scripts, such as `~/bin` or `/usr/local/bin`. For example:
   ```bash
   mkdir -p ~/bin
   cp ../ubuntu-box/scripts/1password/* ~/bin/
   ```

   Alternatively, create symbolic links:
   ```bash
   mkdir -p ~/bin
   ln -s $(pwd)/../ubuntu-box/scripts/1password/* ~/bin/
   ```

2. **Add the Directory to Your PATH**  
   Update your shell configuration file (`~/.bashrc`, `~/.zshrc`, or `~/.profile`) to include the `~/bin` directory in your PATH:
   ```bash
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
   ```

   For `zsh`:
   ```bash
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
   ```

   Apply the changes:
   ```bash
   source ~/.bashrc  # or source ~/.zshrc
   ```

3. **Test the Setup**  
   Verify that the scripts are accessible:
   ```bash
   store-env-to-op.sh --help
   retrieve-env-from-op.sh --help
   ```

   If the commands work without specifying the full path, the setup is complete.

### Benefits of Adding to PATH

- **Convenience**: Run the scripts from any directory without navigating to their location.
- **Clarity**: Shorter, cleaner commands.
- **Efficiency**: Saves time during development and troubleshooting.

## Troubleshooting

### Service Account Authentication

If you're having issues with service account authentication:

1. Verify the token is correctly set in ENV
2. Check service account permissions in 1Password
3. Ensure the token hasn't expired
4. Check audit logs for any access issues

### Common Error Messages

- `Authentication failed`: Check if the service account token is valid and properly set
- `Secret not found`: Verify the secret name matches the expected format
- `Invalid JSON`: Check the format of the stored secrets in 1Password
- `Permission denied`: Verify service account has access to the required vault

## Important Notes

- Service accounts are more secure than individual user accounts for automated processes
- Each environment should use a different service account
- Monitor service account usage through audit logs
- Regularly rotate service account tokens
- Keep error handling and logging comprehensive for easier debugging
- Consider implementing retry logic for network issues
- Use environment-specific configurations when needed
