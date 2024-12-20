# 1Password Environment Management Scripts

A set of scripts to securely store and manage environment variables using 1Password.

## Quick Start (The Basics)

### 1. Store your .env file

```bash
./store-env-to-op.sh -f .env -p myproject -t development
```

### 2. List available environments

```bash
./retrieve-env-from-op.sh -l -p myproject
```

This will show you something like:

```
📋 Available environment files:
env.myproject.development.20241220_123456
env.myproject.staging.20241220_123457
env.myproject.production.20241220_123458
```

### 3. Retrieve your .env file

```bash
# Using the full name from the list
./retrieve-env-from-op.sh -t env.myproject.development.20241220_123456 -o .env
```

### 4. Verify everything worked

```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Common Use Cases

### Working with Multiple Files

```bash
# Backup your existing .env
mv .env .env.backup

# Store new environment
./store-env-to-op.sh -f .env.new -p myproject -t development

# List available versions
./retrieve-env-from-op.sh -l -p myproject

# Retrieve to a new file
./retrieve-env-from-op.sh -t <name-from-list> -o .env.new
```

### Multiple Environments

```bash
# Store each environment
./store-env-to-op.sh -f .env.development -p myproject -t development
./store-env-to-op.sh -f .env.production -p myproject -t production

# List all environments for your project
./retrieve-env-from-op.sh -l -p myproject

# Retrieve specific environment
./retrieve-env-from-op.sh -t <name-from-list> -o .env.development
```

### List All Environments

```bash
# List all environment files
./retrieve-env-from-op.sh -l

# Or search for a partial name
./retrieve-env-from-op.sh -l | grep "myproj"
```

## Script Reference

### store-env-to-op.sh

```bash
./store-env-to-op.sh -f .env -p myproject -t development
```

- `-f .env`: Which file to store (default: .env)
- `-p myproject`: Project name
- `-t development`: Environment type (default: development)
- `-v vault`: Vault name (default: Personal)

### retrieve-env-from-op.sh

```bash
./retrieve-env-from-op.sh -t <name> -o .env
```

- `-t name`: Full name of the environment to retrieve
- `-o .env`: Output file (default: .env)
- `-l`: List available environments
- `-p project`: Filter list by project name
- `-v vault`: Vault name (default: Personal)

### verify-store-and-retrieve.sh

```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

- `-f .env`: File to verify
- `-p myproject`: Project name
- `-t type`: Environment type (default: development)
- `-v vault`: Vault name (default: Personal)
- `-k`: Keep temp files for debugging

## Tips & Tricks

### Always Backup First!

```bash
# Quick backup
cp .env .env.backup

# Dated backup
cp .env ".env.$(date +%Y%m%d)"
```

### Working with Teams

```bash
# Store with team vault
./store-env-to-op.sh -f .env -p "team-project" -v "Team Vault"

# List team environments
./retrieve-env-from-op.sh -l -p "team-project" -v "Team Vault"
```

### Safe Workflow

```bash
# Store and immediately verify
./store-env-to-op.sh -f .env -p myproject && \
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Troubleshooting

### Authentication Issues

```bash
eval $(op signin)
```

### Can't Find Environment

1. List all environments:
   ```bash
   ./retrieve-env-from-op.sh -l
   ```
2. Make sure to use the FULL name when retrieving
3. Double-check your vault name with `op vault list`

### Verification Failures

1. Use -k flag to keep temp files:
   ```bash
   ./verify-store-and-retrieve.sh -f .env -p myproject -k
   ```
2. Check the output for differences
3. Look for extra whitespace or newlines

### .env File Format

Your .env file should be simple key=value pairs:

```bash
# This works fine
DATABASE_URL=postgres://localhost:5432
API_KEY=12345
SECRET_KEY=secret

# Comments and blank lines are okay
# Redis config
REDIS_URL=redis://localhost:6379
```

## Important Notes

- Always use the FULL environment name when retrieving
- Use -l to list available environments
- Make backups before overwriting files
- Run verify if something seems wrong
- Keep your .env files simple: just key=value pairs
