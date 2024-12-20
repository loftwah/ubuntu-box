# 1Password Environment Management Scripts

A set of scripts to securely store and manage environment variables using 1Password.

## Prerequisites

- 1Password CLI installed and configured
- `jq` command-line JSON processor
- Bash shell

## Scripts

### verify-store-and-retrieve.sh

Verifies the integrity of the environment variable storage and retrieval process.

```bash
./verify-store-and-retrieve.sh [-f ENV_FILE] [-v VAULT_NAME] [-p PROJECT_NAME] [-t ENV_TYPE] [-x PREFIX]
```

Options:

- `-f ENV_FILE`: Source .env file (default: .env)
- `-v VAULT_NAME`: 1Password vault (default: Personal)
- `-p PROJECT_NAME`: Project identifier (default: current directory name)
- `-t ENV_TYPE`: Environment type (development/staging/production/testing)
- `-x PREFIX`: Custom prefix for items (default: env)
- `-i`: Interactive vault selection
- `-k`: Keep temporary files for inspection
- `-h`: Show help

Features:

- Performs full store and retrieve cycle
- Compares original and retrieved files
- Ignores comments and whitespace differences
- Shows detailed diff if verification fails
- Option to keep temporary files for debugging

### store-env-to-op.sh

Stores environment variables in 1Password with organized naming and tagging.

```bash
./store-env-to-op.sh [-f ENV_FILE] [-v VAULT_NAME] [-p PROJECT_NAME] [-t ENV_TYPE] [-x PREFIX]
```

Options:

- `-f ENV_FILE`: Source .env file (default: .env)
- `-v VAULT_NAME`: 1Password vault (default: Personal)
- `-p PROJECT_NAME`: Project identifier (default: current directory name)
- `-t ENV_TYPE`: Environment type (development/staging/production/testing)
- `-x PREFIX`: Custom prefix for items (default: env)
- `-i`: Interactive vault selection
- `-h`: Show help

### retrieve-env-from-op.sh

Retrieves environment variables from 1Password.

```bash
./retrieve-env-from-op.sh [-o OUTPUT_FILE] [-v VAULT_NAME] [-p PROJECT_NAME] [-x PREFIX] -t NOTE_TITLE
```

Options:

- `-o OUTPUT_FILE`: Destination file (default: .env)
- `-v VAULT_NAME`: 1Password vault (default: Personal)
- `-p PROJECT_NAME`: Filter by project
- `-x PREFIX`: Item prefix to search for (default: env)
- `-t NOTE_TITLE`: Title of the note to retrieve
- `-i`: Interactive mode
- `-l`: List available environment files
- `-h`: Show help

## Organization System

Items in 1Password are organized using the following naming convention:

```
{prefix}.{project}.{environment}.{timestamp}
```

Example:

```
env.myapp.development.20241220_143022
```

Tags are automatically added:

- env
- secrets
- {project_name}
- {environment_type}

## Examples

Store development environment:

```bash
./store-env-to-op.sh -p myapp -t development
```

List available environments:

```bash
./retrieve-env-from-op.sh -l -p myapp
```

Retrieve specific environment:

```bash
./retrieve-env-from-op.sh -t env.myapp.development.20241220_143022
```

## Security Notes

- Scripts automatically check for 1Password CLI authentication
- Secure notes are tagged for easy searching and organization
- Metadata is included in stored files for tracking
- Overwrite protection for retrieving files
- Environment types are validated

## Best Practices

1. Use consistent project names across your team
2. Include environment type for clarity
3. Use the list feature to find existing environments
4. Back up your environment files before overwriting
5. Use specific vaults for different teams/projects

## Contributing

Feel free to submit issues and enhancement requests!
