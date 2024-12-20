# 1Password Environment Management Scripts

Scripts to store and manage environment variables in 1Password, compatible with both bash scripts and Ruby applications.

## Prerequisites

- Install the [1Password CLI](https://developer.1password.com/docs/cli/get-started/) (`op`).
- Ensure `jq` is installed: `sudo apt install jq` (Linux) or `brew install jq` (Mac).

## Quick Start

> **Note**: `alias op-signin='eval $(op signin)'`

### 1. Store your .env file

```bash
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

### 2. Retrieve your .env file

```bash
./retrieve-env-from-op.sh -p myproject -o .env
# or
./retrieve-env-from-op.sh -t env.myproject.development -o .env
```

### 3. Verify everything works

```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Using with Ruby

The stored secrets are compatible with Ruby applications. Example usage:

```ruby
class DevelopmentSecrets
  def self.setup
    return unless Rails.env.development?

    system('op signin')
    load_secrets
  end

  private

  def self.load_secrets
    # Get the entire JSON object from the note
    json_content = fetch_secret('env.myproject.development', 'notesPlain')
    secrets = JSON.parse(json_content)

    # Load all the keys into ENV
    secrets.each { |key, value| ENV[key.to_s.upcase] = value }
  end

  def self.fetch_secret(item, field)
    `op item get "#{item}" --field "#{field}"`.strip
  end
end
```

## Script Reference

### store-env-to-op.sh

```bash
./store-env-to-op.sh -f .env -p myproject [-t development] [-v "Personal"]
```

- Creates a secure note with name `env.myproject.development`.
- Stores all env vars as JSON in the note's `notesPlain` field.
- Adds tags for easy filtering.

### retrieve-env-from-op.sh

```bash
# List available environments
./retrieve-env-from-op.sh -l -p myproject

# Retrieve specific environment
./retrieve-env-from-op.sh -t env.myproject.development -o .env
```

### verify-store-and-retrieve.sh

```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

Verifies that storage and retrieval work correctly.

## Common Examples

### Multiple Environments

```bash
# Store different environments
./store-env-to-op.sh -f .env.development -p myproject -t development
./store-env-to-op.sh -f .env.production -p myproject -t production

# List all environments
./retrieve-env-from-op.sh -l -p myproject

# Get specific environment
./retrieve-env-from-op.sh -t env.myproject.production -o .env.production
```

### Team Vaults

```bash
./store-env-to-op.sh -f .env -p myproject -v "Team Vault"
./retrieve-env-from-op.sh -t env.myproject.development -v "Team Vault" -o .env
```

## Troubleshooting

### Authentication

```bash
eval $(op signin)
```

### Can't Find Environment

```bash
# List all environments
./retrieve-env-from-op.sh -l

# List environments for specific project
./retrieve-env-from-op.sh -l -p myproject
```

### View Raw JSON

```bash
op item get env.myproject.development --field notesPlain
```

### Error Codes

- `❌ Note not found`: The title or project name doesn’t exist in the specified vault.
- `❌ Failed to retrieve notesPlain content`: The field might be missing or corrupted.

## Important Notes

- Each `.env` file is stored as a single secure note with JSON content.
- Note names follow pattern: `env.{project}.{environment}`.
- Same data accessible from both bash scripts and Ruby.
- All env vars stored in the `notesPlain` field as JSON.
- Use `op item get` to access individual fields if needed.
