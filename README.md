# Ubuntu Box 2025

A modern, secure Ubuntu development environment for AWS, featuring automated setup of development tools, security configurations, and AWS integrations.

## Features

- **Pre-configured Development Tools:**

  - Node.js 20, Go 1.22, Rust, Ruby 3.3, Python 3.12
  - Modern package managers: mise, uv, bun
  - Essential tools: Docker, git, vim, fzf, ripgrep, jq, yq
  - AWS CLI and integrations

- **Security First:**

  - Hardened SSH configuration
  - fail2ban, rkhunter, and AIDE
  - Automated security updates
  - CloudWatch monitoring
  - Audit logging

- **AWS Integration:**
  - EFS mounting capability
  - CloudWatch metrics and logs
  - Systems Manager integration
  - IAM role-based access

## Quick Start

1. **Prerequisites:**

   ```bash
   # Install tfenv
   git clone https://github.com/tfutils/tfenv.git ~/.tfenv
   echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc

   # Install and use Terraform 1.0.0 or later
   tfenv install latest
   tfenv use latest

   # Configure AWS credentials
   aws configure
   ```

2. **Deploy:**

   ```bash
   cd ec2-environment/terraform
   terraform init
   terraform apply
   ```

3. **Connect:**

   ```bash
   # Using SSH
   ./scripts/connect.sh ssh

   # Using AWS Systems Manager
   ./scripts/connect.sh ssm
   ```

## Post-Installation Setup

The following tools need to be installed manually after connecting to the instance:

### 1. Mise Installation

```bash
# Set proper ownership
sudo chown -R ubuntu:ubuntu /home/ubuntu

# Install mise
curl https://mise.run | sh
echo 'eval "$(/home/ubuntu/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
mise doctor

# Configure mise
cat > ~/.mise.toml << 'EOF'
[tools]
node = "latest"
go = "latest"
rust = "latest"
ruby = "latest"
python = "latest"
EOF

# Trust and install tools
/home/ubuntu/.local/bin/mise trust
/home/ubuntu/.local/bin/mise install
```

### 2. UV Installation

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 3. Bun Installation

```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
```

## Known Issues & Future Improvements

1. Automate post-installation setup:

   - Mise installation and configuration
   - UV installation
   - Bun installation

2. Improve error handling in cloud-init
3. Add verification steps for tool installation
4. Add automated testing

## Deployment Options

- **Region:** Supports us-west-1, ap-southeast-2, ap-southeast-4, us-east-1, eu-west-1
- **Architecture:** Choose between amd64 or arm64

Example deployment with custom options:

```bash
terraform apply -var="region=ap-southeast-2" -var="arch=arm64"
```

## Management Scripts

- `connect.sh`: SSH and SSM connection management
- `monitor.sh`: System monitoring and health checks
- `mount_efs.sh`: EFS filesystem management
- `verify.sh`: Environment verification

## Monitoring

Monitor your instance through:

- CloudWatch metrics dashboard
- Real-time system stats: `./scripts/monitor.sh`
- Security status: `./scripts/monitor.sh -s`

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

4. **Verify everything is installed**

```bash
verify
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

## Security

- SSH access is key-based only
- Root login is disabled
- Automatic security updates
- Regular security scans with Lynis
- Intrusion detection with fail2ban

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - See [LICENSE](LICENSE) for details.

## Documentation

- [Detailed Design](design.md)
- [Implementation Plan](plan.md)

## Support

For issues and feature requests, please use the GitHub issue tracker.
