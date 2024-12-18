## Docker Development Environment

An alternative to the EC2 deployment, this Docker-based environment provides the same tools and configurations in a local container.

### Prerequisites

- Docker Engine 24.0 or later
- Docker Compose v2.22 or later
- AWS credentials configured locally (if using AWS services)

### Quick Start

1. **Clone the repository:**

   ```bash
   git clone https://github.com/loftwah/ubuntu-box-2025.git
   cd ubuntu-box-2025
   ```

2. **Build and start the container:**

   ```bash
   docker compose up -d
   ```

3. **Connect to the container:**
   ```bash
   docker compose exec ubuntu-box bash
   ```

### Features

The Docker environment includes all tools from the EC2 setup:

- Ubuntu 24.04 (Noble Numbat) base
- Python 3.12 with UV package manager
- Node.js 20 and Bun 1.0.21
- Go 1.22
- AWS CLI 2.22.7
- Development tools (git, vim, fzf, ripgrep, etc.)

### Directory Structure

```
ubuntu-box-2025/
├── Dockerfile           # Main container definition
├── docker-compose.yml   # Container orchestration
├── verify.sh           # Environment verification script
└── .env                # Environment variables (create from .env.example)
```

### Common Tasks

```bash
# Start the environment
docker compose up -d

# Enter the container
docker compose exec ubuntu-box bash

# Stop the environment
docker compose down

# Rebuild after changes
docker compose build --no-cache

# Run a specific command
docker compose exec ubuntu-box [command]

# Verify the environment
docker compose exec ubuntu-box verify
```

### Volume Mounts

The environment includes several persistent volumes:

- `uv_cache`: Python package cache
- `bun_cache`: JavaScript package cache
- `go_cache`: Go module cache

Your AWS and SSH configurations are mounted read-only:

- `~/.aws`: AWS credentials and configuration
- `~/.ssh`: SSH keys and configuration

### Port Mappings

The following ports are mapped to your host machine:

- 3000: Node.js/Bun applications
- 8000: Python applications
- 9000: Go applications

### Customization

- Modify `Dockerfile` to add or change installed packages
- Adjust `docker-compose.yml` for different volume mounts or port mappings
- Edit environment variables in `.env` file
