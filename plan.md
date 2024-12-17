# Ubuntu Box 2025 - Implementation Plan

## Phase 1: EC2 Development Box

Milestone: Fully functional development environment

1. **Infrastructure Setup**

   - Terraform AWS provider configuration
   - EC2 instance with Ubuntu 24.04
   - Security groups (inbound SSH)
   - IAM role (CloudWatch, S3, ECR permissions)
   - CloudWatch agent configuration
   - SSH key pair

2. **Development Environment**

   - Base system packages
   - Mise installation and setup
   - Language runtimes (Node.js, Go, Rust, Ruby, Python)
   - Development tools (Bun, uv, fd, fzf, ripgrep, jq, yq)
   - AWS CLI and configuration

3. **Security & Management**
   - Security tools (Lynis, fail2ban, rkhunter, aide)
   - SSH hardening
   - EFS mount/unmount capability

VERIFIED = Can SSH in, use all dev tools, run security scan, mount EFS

## Phase 2: Docker Environment

Milestone: Local container development ready

1. **Docker Setup**

   - Docker Engine installation
   - Docker configuration
   - User permissions

2. **Container Build**
   - Base Dockerfile with Ubuntu 24.04
   - Development tools layer
   - Runtime environments layer
   - Build script creation

VERIFIED = Can build and run development container locally

## Phase 3: Container Registry & Orchestration

Milestone: Production container environment

1. **Registry Setup**

   - ECR repository creation
   - Push/pull authentication
   - Build and push scripts

2. **Container Orchestration**
   - ECS cluster setup
   - Task definition with container
   - Service configuration
   - Auto-scaling rules

VERIFIED = Container running in ECS, can push/pull from ECR

# Implementation Guidelines

- Each phase must be completely verified before moving to next phase
- All configurations and scripts must be documented as created
- Each phase must result in a fully working system
- Security considerations must be addressed in each phase
- Verification steps must be automated where possible
