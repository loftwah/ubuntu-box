# proompt.sh Usage Guide

`proompt.sh` is a versatile script for generating AI prompts from project files. It helps you combine and format your project's code files in a way that's ideal for AI analysis.

## Installation

You can run the script directly from your project, but it's often convenient to install it system-wide. Here are your options on Ubuntu:

### 1. User-specific Installation (Recommended)

```bash
# Create user bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Copy script to your user bin directory
cp scripts/proompt.sh ~/.local/bin/proompt

# Make it executable
chmod +x ~/.local/bin/proompt

# Add to PATH if not already added
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Reload your shell configuration
source ~/.bashrc
```

Now you can run `proompt` from anywhere!

### 2. Alternative User Installation

Some older systems use `~/bin` instead:

```bash
# Create user bin directory if it doesn't exist
mkdir -p ~/bin

# Copy script
cp scripts/proompt.sh ~/bin/proompt

# Make it executable
chmod +x ~/bin/proompt

# Add to PATH if not already added
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3. System-wide Installation (Requires sudo)

```bash
# Copy to system bin (requires sudo)
sudo cp scripts/proompt.sh /usr/local/bin/proompt

# Make it executable
sudo chmod +x /usr/local/bin/proompt
```

### Verify Installation

```bash
# Check if proompt is in your PATH
which proompt

# Should show something like:
# ~/.local/bin/proompt
# or ~/bin/proompt
# or /usr/local/bin/proompt

# Test it
proompt -h
```

⚠️ **Note**: After installation, you can use `proompt` instead of `proompt` in all examples below.

## ⚠️ Before You Start

1. Make sure you're in the root of your git repository
2. The script must be executable:

   ```bash
   # If the script is in the current directory
   chmod +x proompt.sh

   # If the script is in a scripts directory
   chmod +x scripts/proompt.sh
   ```

3. Always run the script from your project root, NOT from inside the scripts directory:

   ```bash
   # ✅ CORRECT (from project root):
   ./scripts/proompt.sh

   # ❌ WRONG (from scripts directory):
   ./proompt.sh
   ```

## Quick Start

```bash
# Get help and see all options
./scripts/proompt.sh -h

# Start with a project summary (safest first step)
./scripts/proompt.sh -s

# Use default settings with size limit (recommended for first full run)
./scripts/proompt.sh -d -m=500000
```

## Handling Output

The script can generate a lot of output. Here are the recommended ways to handle it:

### 1. Save to File (✅ RECOMMENDED)

```bash
# Save to a file (most reliable method)
./scripts/proompt.sh -d > project-analysis.md

# Save with timestamp (useful for multiple runs)
./scripts/proompt.sh -d > "analysis-$(date +%Y%m%d-%H%M%S).md"
```

### 2. Copy to Clipboard

Different systems have different clipboard commands:

```bash
# On macOS
./scripts/proompt.sh -d | pbcopy

# On Linux with xclip
./scripts/proompt.sh -d | xclip -selection clipboard

# On Linux with xsel
./scripts/proompt.sh -d | xsel --clipboard
```

⚠️ **IMPORTANT CLIPBOARD WARNINGS**:

- xclip/xsel require an X server - won't work in WSL or SSH sessions without X forwarding
- Clipboard might fail with large outputs
- Different systems handle newlines differently
- **Always test clipboard content before closing your terminal**
- When in doubt, use the file output method instead

## Command Line Options

| Option                | Description                                          | Example       |
| --------------------- | ---------------------------------------------------- | ------------- |
| `-i, --ignore-case`   | Ignore case when matching file extensions            | `-i`          |
| `-x, --extensions`    | Specify file extensions to include (comma-separated) | `-x=js,ts,md` |
| `-t, --tree`          | Print the project tree                               | `-t`          |
| `-d, --defaults`      | Use the default settings (recommended)               | `-d`          |
| `-n, --no-ext`        | Include files without extensions                     | `-n`          |
| `-m, --max-size=SIZE` | Skip files larger than SIZE bytes                    | `-m=500000`   |
| `-s, --summary`       | Generate a project summary                           | `-s`          |
| `-h, --help`          | Show help message and exit                           | `-h`          |

## Safe Usage Examples

### 1. First-Time Project Exploration (Safest)

```bash
# Start with just a summary
./scripts/proompt.sh -s > summary.md

# Then try with common code files and size limit
./scripts/proompt.sh -x=md,sh,yml,tf -m=100000 > analysis.md
```

### 2. Default Analysis (Standard)

```bash
# Use defaults with size limit to avoid huge files
./scripts/proompt.sh -d -m=500000 > full-analysis.md
```

### 3. Documentation Focus

```bash
# Look at just documentation and config
./scripts/proompt.sh -x=md,yml,yaml,txt -s > docs-analysis.md
```

### 4. Code Review

```bash
# Focus on specific file types with size limit
./scripts/proompt.sh -x=js,ts,py,rb -m=250000 > code-review.md
```

## Common Pitfalls and Solutions

### 1. "Not in a git repository"

```bash
# Check if you're in a git repo
git status

# If not, you're in the wrong directory. Find your git root:
git rev-parse --git-dir
cd $(git rev-parse --show-toplevel)  # Go to git root
```

### 2. "Permission denied"

```bash
# Make script executable
chmod +x scripts/proompt.sh

# Check if script is executable
ls -l scripts/proompt.sh  # Should show -rwxr-xr-x
```

### 3. "Extensions cannot be empty"

```bash
# Must either specify extensions
./scripts/proompt.sh -x=js,py

# Or use defaults
./scripts/proompt.sh -d

# Or include files without extensions
./scripts/proompt.sh -n
```

### 4. Output is too large

```bash
# Use a smaller set of extensions
./scripts/proompt.sh -x=md,yml

# Add a file size limit
./scripts/proompt.sh -d -m=100000

# Focus on specific file types
./scripts/proompt.sh -x=sh,yml -m=500000
```

### 5. Missing files

Checklist:

- Are you in the correct directory? Use `pwd` to check
- Run `git ls-files` to see what files git knows about
- Check your extension list matches your files
- Verify files aren't ignored by git: `git check-ignore [file]`
- Check file sizes if using `-m`: `ls -lh [file]`

## Best Practices

1. **Always start with summary**

   ```bash
   ./scripts/proompt.sh -s > summary.md
   ```

2. **Use size limits**

   ```bash
   ./scripts/proompt.sh -d -m=500000 > analysis.md
   ```

3. **Save outputs to files**

   - More reliable than clipboard
   - Can be reviewed before sharing
   - Won't get lost if terminal closes

4. **Regular backups**

   ```bash
   # Create timestamped outputs
   ./scripts/proompt.sh -d > "analysis-$(date +%Y%m%d).md"
   ```

5. **Security**
   - Always review output before sharing
   - Watch for sensitive data in .env.example files
   - Use `-m` to avoid large files that might contain unexpected content
