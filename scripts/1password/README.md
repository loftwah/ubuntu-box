# 1Password Environment Management Scripts

A set of scripts to securely store and manage environment variables using 1Password.

## Quick Start (The Basics)

### 1. Store your .env file
```bash
./store-env-to-op.sh -f .env -p myproject
```

### 2. List available environments (instead of remembering timestamps!)
```bash
./retrieve-env-from-op.sh -l -p myproject
```
This will show you something like:
```
Available environment files:
env.myproject.development.20241220_123456
env.myproject.staging.20241220_123457
env.myproject.production.20241220_123458
```

### 3. Retrieve your .env file
Copy the full name from the list above or just use the project name:
```bash
# Using project name (will list available envs if multiple exist)
./retrieve-env-from-op.sh -p myproject -o .env

# Or using the full name (if you know it)
./retrieve-env-from-op.sh -t env.myproject.development.20241220_123456 -o .env
```

### 4. Verify everything worked
```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Common Use Cases

### "Help! I don't want to overwrite my existing .env!"
```bash
# Backup your existing .env
mv .env .env.backup

# Store new environment
./store-env-to-op.sh -f .env.new -p myproject

# List available versions
./retrieve-env-from-op.sh -l -p myproject

# Retrieve to a new file
./retrieve-env-from-op.sh -p myproject -o .env.new
```

### "I have multiple environments (.env.development, .env.production, etc.)"
```bash
# Store each environment
./store-env-to-op.sh -f .env.development -p myproject -t development
./store-env-to-op.sh -f .env.production -p myproject -t production

# List all environments for your project
./retrieve-env-from-op.sh -l -p myproject

# Retrieve specific environment (it will show you available options)
./retrieve-env-from-op.sh -p myproject -t development -o .env.development
```

### "I don't remember what I named my project!"
```bash
# List all environment files
./retrieve-env-from-op.sh -l

# Or search for a partial name
./retrieve-env-from-op.sh -l | grep "myproj"
```

### "I want to make sure nothing got messed up"
```bash
# Verify any environment file
./verify-store-and-retrieve.sh -f .env -p myproject

# Keep the temp files if something goes wrong
./verify-store-and-retrieve.sh -f .env -p myproject -k
```

## Script Reference

### store-env-to-op.sh
```bash
./store-env-to-op.sh -f .env -p myproject [-t development]
```
- `-f .env`: Which file to store (default: .env)
- `-p myproject`: Project name
- `-t development`: Environment type (default: development)
- `-i`: Interactive mode (shows available vaults)

### retrieve-env-from-op.sh
```bash
./retrieve-env-from-op.sh -p myproject [-o .env]
```
- `-p myproject`: Project name
- `-o .env`: Output file (default: .env)
- `-l`: List available environments
- `-i`: Interactive mode

### verify-store-and-retrieve.sh
```bash
./verify-store-and-retrieve.sh -f .env -p myproject
```
- `-f .env`: File to verify
- `-p myproject`: Project name
- `-k`: Keep temp files if something goes wrong

## Tips & Tricks

### Always backup first!
```bash
# Quick backup
cp .env .env.backup

# Dated backup
cp .env ".env.$(date +%Y%m%d)"
```

### Working with teams?
```bash
# Store with team name
./store-env-to-op.sh -f .env -p "team-project" -v "Team Vault"

# List team environments
./retrieve-env-from-op.sh -l -p "team-project" -v "Team Vault"
```

### Want to be extra careful?
```bash
# Store and immediately verify
./store-env-to-op.sh -f .env -p myproject && \
./verify-store-and-retrieve.sh -f .env -p myproject
```

## Troubleshooting

### "It says I'm not logged in!"
```bash
eval $(op signin)
```

### "It can't find my environment!"
1. List all environments:
   ```bash
   ./retrieve-env-from-op.sh -l
   ```
2. Check if your project name is correct
3. Try using interactive mode (-i flag)

### "I have multiple values in my .env file"
Your .env file can contain as many key-value pairs as you need:
```bash
# This works fine
DATABASE_URL=postgres://localhost:5432
API_KEY=12345
SECRET_KEY=secret

# Even with comments and blank lines
# Redis config
REDIS_URL=redis://localhost:6379
```

### "The verification failed!"
1. Use the -k flag to keep temporary files:
   ```bash
   ./verify-store-and-retrieve.sh -f .env -p myproject -k
   ```
2. Check the output for differences
3. Make sure your .env file has no trailing spaces

### "I got an error about the vault!"
Use interactive mode to see available vaults:
```bash
./store-env-to-op.sh -i -f .env -p myproject
```

## Remember!
- You don't need to remember timestamps
- Always use `-l` to list available environments
- When in doubt, use `-i` for interactive mode
- Make backups before overwriting files
- Use the verify script if something seems wrong