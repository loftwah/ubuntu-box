# 1Password Environment Management Scripts

Scripts to store environment variables in 1Password, with each variable as a separate field for easy access.

## Quick Start

### Store your .env file

```bash
./store-env-to-op.sh -f .env -p myproject
```

This creates a secure note where each line in your .env becomes a field in 1Password:

```
HELLO=WORLD    ->  Field "HELLO" with value "WORLD"
GDAY=MATE      ->  Field "GDAY" with value "MATE"
```

### Retrieve environment variables

Get all variables (complete .env):

```bash
./retrieve-env-from-op.sh -t env.myproject.development.20241220_123456 -o .env
```

Get a single variable:

```bash
# Get just the DATABASE_URL
op item get env.myproject.development.20241220_123456 --fields DATABASE_URL
```

### List available environments

```bash
./retrieve-env-from-op.sh -l -p myproject
```

### Verify everything worked

```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Why This Approach?

- Each environment variable is a separate field in 1Password
- Easy to retrieve single values when needed (e.g., just the API key)
- Works great with 1Password CLI filtering and field selection
- Simple to integrate with other tools and scripts

## Script Reference

### store-env-to-op.sh

Stores each line in your .env as a separate field in a 1Password secure note.

```bash
./store-env-to-op.sh -f .env -p myproject [-t development] [-v "Personal"]
```

### retrieve-env-from-op.sh

Get all fields as .env or use 1Password CLI for single fields.

```bash
# Get all fields as .env
./retrieve-env-from-op.sh -t <name> -o .env

# Or use op cli directly for single fields
op item get <name> --fields DATABASE_URL
```

### verify-store-and-retrieve.sh

Verifies that storage and retrieval work correctly.

```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Common Examples

### Get a specific value

```bash
# Get just the API key
op item get env.myproject.development.20241220_123456 --fields API_KEY
```

### Store multiple environments

```bash
# Store each environment
./store-env-to-op.sh -f .env.development -p myproject -t development
./store-env-to-op.sh -f .env.production -p myproject -t production

# List them
./retrieve-env-from-op.sh -l -p myproject

# Get a specific field from production
op item get env.myproject.production.20241220_123456 --fields DATABASE_URL
```

### Working with teams

```bash
# Store in team vault
./store-env-to-op.sh -f .env -p "team-project" -v "Team Vault"

# Get production database URL from team vault
op item get env.team-project.production.20241220_123456 --fields DATABASE_URL --vault "Team Vault"
```

## Troubleshooting

### Authentication

```bash
eval $(op signin)
```

### Can't find environment

```bash
# List all environments
./retrieve-env-from-op.sh -l

# List environments for specific project
./retrieve-env-from-op.sh -l -p myproject
```

### Check field names

```bash
# See all fields in an environment
op item get env.myproject.development.20241220_123456 --format=json | jq '.fields[] | .label'
```

## Important Notes

- Each line in .env becomes a field in 1Password
- Use `op item get --fields FIELD_NAME` for single values
- Use the scripts for full .env management
- Keep field names simple (no spaces or special characters)
