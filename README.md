# Loftwah's Ubuntu Box for 2025

## Overview

**Loftwah’s Ubuntu Box for 2025** is a single-environment setup that can be deployed across multiple AWS regions and architectures. It leverages a custom Ubuntu-based AMI and a Docker-based ECS environment, providing a robust set of tools, runtimes, AWS integrations, and secure access methods. The environment is managed with Terraform, and easily configured via `region` and `arch` variables.

**New Enhancements:**

- **ECR Integration:** Store and retrieve Docker images from Amazon ECR.
- **Security Groups & IAM:** Detailed configuration for secure networking and IAM roles for both AMI and ECS.
- **Build & Push Scripts (buildx):** Automated scripts to build and push multi-arch Docker images.
- **Monitoring Scripts:** Additional `monitor.sh` scripts for both EC2 (AMI) and ECS environments for real-time checks.
- **connect.sh Scripts:** Simplified `connect.sh` utilities for both EC2 and ECS to streamline SSM and SSH/Exec access.

## Core Principles

- **Single Environment, Multi-Region:** No dev/prod split, just select AMI IDs per region/arch.
- **Full Toolset (verify.sh):** Ensure all required tools and runtimes are present.
- **Secure & Accessible:** SSH/SSM for AMI, ECS Exec (SSM) for ECS containers.
- **AWS Integrations:** EFS, S3, RDS, ElastiCache, plus ECR for container images.
- **Monitoring & Alerting:** CloudWatch metrics, logs, alarms, plus optional custom `monitor.sh`.

## Supported AMIs by Region & Architecture

The following Ubuntu 24.04 LTS (Noble Numbat) AMIs are supported:

| Region         | Name         | Version   | Arch  | Storage         | Date     | AMI ID                | Virtualization |
| -------------- | ------------ | --------- | ----- | --------------- | -------- | --------------------- | -------------- |
| us-west-1      | Noble Numbat | 24.04 LTS | amd64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0a9cd4a0a5f6c06bb | hvm            |
| us-west-1      | Noble Numbat | 24.04 LTS | arm64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0de5737cddf1c59b8 | hvm            |
| ap-southeast-2 | Noble Numbat | 24.04 LTS | amd64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0eb5e2a4908880da3 | hvm            |
| ap-southeast-2 | Noble Numbat | 24.04 LTS | arm64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0e4f8a9457c962abb | hvm            |
| ap-southeast-4 | Noble Numbat | 24.04 LTS | amd64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0fcd26ca3ba0585b6 | hvm            |
| ap-southeast-4 | Noble Numbat | 24.04 LTS | arm64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0299283ac4b0e73a9 | hvm            |
| us-east-1      | Noble Numbat | 24.04 LTS | amd64 | hvm:ebs-ssd-gp3 | 20241206 | ami-00f3c44a2de45a590 | hvm            |
| us-east-1      | Noble Numbat | 24.04 LTS | arm64 | hvm:ebs-ssd-gp3 | 20241206 | ami-070669ed9d7e8c691 | hvm            |
| eu-west-1      | Noble Numbat | 24.04 LTS | amd64 | hvm:ebs-ssd-gp3 | 20241206 | ami-0d8bd47e6d44801e1 | hvm            |
| eu-west-1      | Noble Numbat | 24.04 LTS | arm64 | hvm:ebs-ssd-gp3 | 20241206 | ami-01cbbf6d4d6a0ee3b | hvm            |

A Terraform map will reference these AMIs by `region` and `arch`.

## Tooling & Runtimes: AMI vs. Docker

**On the AMI (EC2 Instance):**

- **OS Security & Monitoring Tools:** `lynis`, `fail2ban`, `rkhunter`, `aide`
- **Base Tools:** `curl`, `wget`, `git`, `vim`, `nano`, `build-essential`, `python3-pip`
- **Runtimes (Mise):** Node.js (20), Go (1.22), Rust (latest), Ruby (3.3), Python (3.12)
- **Additional Tools:** Bun, uv, fd, fzf, ripgrep, AWS CLI, ImageMagick, jq, yq, htop, ncdu, zip/unzip
- **Docker:** Installed via `get.docker.com`
- **EFS Utils:** `amazon-efs-utils` for mounting/unmounting EFS.
- **ECR Login:** `aws ecr get-login-password` integrated into setup for pulling/pushing images.
- **Scripts:**
  - `build.sh` and `buildx` scripts for building/pushing Docker images to ECR.
  - `monitor.sh` for on-demand checks (CPU load, disk usage, etc.).
  - `connect.sh` for easy SSH or SSM session establishment.

**On the Docker Container (ECS Environment):**

- **No OS Security Tools:** No `lynis`, `fail2ban`, `rkhunter`, `aide`.
- **Runtimes:** Copied from official images: Node, Go, Rust, Ruby, Python, plus Bun, uv, fd, fzf, ripgrep, AWS CLI, ImageMagick, jq, yq, htop, ncdu, zip/unzip.
- **No SSH Needed:** Use ECS Exec (SSM) and a `connect.sh` script that runs `aws ecs execute-command`.
- **Minimal EFS:** Typically omit EFS utils unless required. If EFS needed for ECS tasks, mount via ECS Task Definition configuration.
- **monitor.sh for ECS:** Could run a simplified `monitor.sh` inside the container (via ECS Exec) for debugging resource usage in real-time.

This ensures `verify.sh` passes on AMI and Docker (for non-OS-level tools), guaranteeing a consistent developer experience.

## AWS Services Integration

- **ECR:**  
  Store built Docker images. The `build.sh` (or `buildx` version `buildx.sh`) script on the AMI can login to ECR, build multi-architecture images, and push them. ECS tasks pull from ECR.
- **EFS, S3, RDS, ElastiCache:**
  - IAM roles grant access.
  - Security groups must allow access to RDS/ElastiCache endpoints.
  - EFS can be mounted on AMI and ECS tasks. Ensure proper unmounting on AMI and ECS Task definition for ECS.

## Access & Security

- **SSH Keys:**  
  Terraform’s `aws_key_pair` for AMI SSH. SG allows `0.0.0.0/0` temporarily.  
  `connect.sh` script can simplify SSH by reading instance details from Terraform outputs.

- **SSM Access:**
  AMI and ECS both use SSM.  
  `connect.sh` can run `aws ssm start-session` for AMI or `aws ecs execute-command` for ECS containers.

- **IAM & Networking:**
  - IAM roles for EC2 and ECS tasks include `ecr:GetAuthorizationToken`, `s3:*` (as needed), `rds:Connect`, `elasticache:*`, and `efs:*`.
  - Default VPC and subnets if not provided.
  - Security groups refined: separate SGs for AMI and ECS tasks, allowing outbound internet access for ECR, inbound SSH for AMI, and internal access for RDS/ElastiCache.

## Monitoring & Alerting

- **CloudWatch Agent on AMI:** CPU, memory, disk metrics.
- **ECS Logs to CloudWatch Logs:** ECS tasks log for analysis.
- **CloudWatch Alarms:** On CPU > 80%, memory > 80%, disk < 10%. Alarms trigger SNS notifications.
- **monitor.sh Scripts:**
  - On AMI: `monitor.sh` could quickly show system load, disk usage, top processes.
  - On ECS: `monitor.sh` run via ECS Exec for container-level checks.

## Maintenance & Updates

- **Rebuild AMI:** Update packages, run `mise` for new runtime versions.
- **Update Docker Images:**
  - `buildx.sh` for multi-arch builds.
  - Push updated images to ECR.
- **Run verify.sh:** Ensure environment integrity after updates.

## Recommended Directory Structure

```
project-root/
├─ terraform/
│  ├─ main.tf
│  ├─ variables.tf        # region, arch
│  ├─ outputs.tf
│  ├─ providers.tf
│  ├─ locals.tf           # AMI maps keyed by region & arch
│  ├─ modules/
│  │  ├─ ami/
│  │  │  ├─ main.tf
│  │  │  ├─ variables.tf
│  │  │  ├─ outputs.tf
│  │  │  └─ scripts/
│  │  │     ├─ cloud-init.yml
│  │  │     ├─ mise.toml
│  │  │     ├─ setup.sh      # Installs security tools, uv, bun, docker, efs, etc.
│  │  ├─ ecs/
│  │  │  ├─ main.tf          # ECS cluster, service, task definition
│  │  │  ├─ variables.tf
│  │  │  ├─ outputs.tf
│  │  ├─ networking/
│  │  │  ├─ main.tf          # SGs, VPC defaults
│  │  │  ├─ variables.tf
│  │  │  ├─ outputs.tf
│  │  └─ monitoring/
│  │     ├─ main.tf          # CW alarms, log groups
│  │     ├─ variables.tf
│  │     ├─ outputs.tf
│  ├─ terraform.tfvars       # default region if wanted
│  └─ README.md
│
├─ docker/
│  ├─ Dockerfile             # Mirrors AMI tools (minus OS security)
│  ├─ verify.sh              # Check tool presence
│  ├─ build.sh               # Simple build & push script
│  ├─ buildx.sh              # Multi-arch build & push via buildx to ECR
│  ├─ monitor.sh             # Container-level checks if needed
│  ├─ connect.sh             # ECS Exec simplified script
│  └─ README.md
│
├─ scripts/
│  ├─ setup_ami.sh
│  ├─ mount_efs.sh           # Clean EFS mount/unmount on AMI
│  ├─ verify_local.sh        # Run after SSH/SSM into AMI
│  ├─ monitor.sh             # AMI-level system checks
│  ├─ connect.sh             # SSH/SSM session simplified for AMI
│  └─ README.md
│
├─ docs/
│  ├─ DESIGN.md              # Loftwah’s Ubuntu Box for 2025 (this doc)
│  ├─ MONITORING.md          # Detailed monitoring & alerting steps
│  ├─ AWS_SERVICES.md        # EFS, S3, RDS, ElastiCache usage examples
│  ├─ SECURITY.md            # Hardening, SSH key rotation, fail2ban configs
│  └─ ECR.md                 # ECR usage guidelines, buildx instructions
│
└─ .gitignore
```

## Putting It All Together

- **AMI:**  
  Launch using region/arch-specific AMIs.  
  Includes OS security tools, Docker, EFS utils, full runtime & toolset.

- **Docker & ECS:**  
  Docker image built and stored in ECR.  
  ECS tasks pull from ECR and run the same runtimes/tools minus OS-level security.

- **Access & Maintenance:**

  - `connect.sh` for quick SSH/SSM/ECS Exec.
  - `buildx.sh` for multi-arch image builds.
  - `monitor.sh` scripts for quick system checks on both AMI and ECS.

- **AWS Integration & Security:**
  IAM roles, security groups, and default VPC usage ensure minimal config overhead.
  ECR provides a secure, private registry for images.
  CloudWatch offers metrics, logs, and alarms for proactive monitoring.
