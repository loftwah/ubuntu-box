# Loftwah's Ubuntu Box for 2025 (Enhanced Design Document)

## Overview

**Loftwah's Ubuntu Box for 2025** describes a unified development environment that can be deployed in AWS via **two mutually exclusive options**:

1. **EC2-based AMI environment** (Ubuntu 24.04 LTS)
2. **ECS-based Docker environment**

Both approaches provide a consistent set of tools, runtimes, and AWS integrations. Each uses Terraform for infrastructure provisioning and scripts for setup, verification, and connectivity. The environment is selected by choosing either the EC2 directory or the ECS directory—never both simultaneously.

**Key Enhancements:**

- **Hard-coded SSH Key (EC2):** A user-provided SSH public key is directly embedded in the Terraform configuration, ensuring consistent access without manual key distribution.
- **ECR Integration:** Both AMI and ECS leverage Amazon ECR for storing and retrieving Docker images.
- **Security & IAM:** Detailed configuration of IAM roles, policies, and security groups for robust AWS integration.
- **Build & Push (Multi-Arch):** `buildx` scripts for building and pushing multi-architecture Docker images to ECR.
- **Monitoring Scripts:** `monitor.sh` scripts for real-time environment checks. AMI and ECS have tailored versions.
- **Connect Scripts:** `connect.sh` utilities for simplified SSH (AMI) or ECS Exec (ECS) access.
- **Docker Installation (EC2):** Ensured via `get.docker.com` script.
- **uv Installation (EC2):** Installed via official `uv` script.
- **uv in ECS:** Pre-packaged into the ECS container image (built from an official `uv`-enabled base image).

This document contains everything needed to instruct an LLM on how to build and manage this setup.

---

## Core Principles

- **Single Environment, Multi-Region:**  
  No dev/prod splits. Select AMI by region and architecture as needed.
- **Choice of Deployment:**  
  EITHER deploy on EC2 with a custom Ubuntu-based AMI OR deploy on ECS with Docker containers. Not both at once.

- **Full Toolset Verification:**  
  A `verify.sh` script ensures all required tools and runtimes are installed consistently on AMI and ECS environments.

- **Secure & Accessible:**
  - EC2: SSH/SSM for instance access.
  - ECS: ECS Exec (SSM) for container access.
- **AWS Integrations:**  
  Integrated with EFS, S3, RDS, ElastiCache, ECR. IAM roles and Security Groups manage permissions and access.

- **Monitoring & Alerting:**  
  CloudWatch metrics, logs, and alarms. On-demand checks via `monitor.sh`.

---

## AMI Details: Ubuntu 24.04 LTS

The following AMIs (Ubuntu 24.04 LTS, "Noble Numbat") are supported. Terraform maps AMI IDs by `region` and `arch`:

| Region         | Arch  | AMI ID                |
| -------------- | ----- | --------------------- |
| us-west-1      | amd64 | ami-0a9cd4a0a5f6c06bb |
| us-west-1      | arm64 | ami-0de5737cddf1c59b8 |
| ap-southeast-2 | amd64 | ami-0eb5e2a4908880da3 |
| ap-southeast-2 | arm64 | ami-0e4f8a9457c962abb |
| ap-southeast-4 | amd64 | ami-0fcd26ca3ba0585b6 |
| ap-southeast-4 | arm64 | ami-0299283ac4b0e73a9 |
| us-east-1      | amd64 | ami-00f3c44a2de45a590 |
| us-east-1      | arm64 | ami-070669ed9d7e8c691 |
| eu-west-1      | amd64 | ami-0d8bd47e6d44801e1 |
| eu-west-1      | arm64 | ami-01cbbf6d4d6a0ee3b |

---

## Hard-Coded SSH Key (EC2)

Include the following SSH public key in the Terraform `aws_key_pair` resource:

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFghqMnnpyftkhyAnsg82i+F9nw8Xh9U/8u/J2DggLcwlOUKnlG8T55gSMchE81n+pUdjn6fG6S85aQhCdAQANzjC+eQYiFU184ZqWBIS1DfnJwfqGLeExjl2HYvgcjsailO5EIWT0RKCTLpLGtW2dNA6qtj4SJy5nJP1C3l5R1H5UNT90MXh41E0/7wCNv2eNWZeWaWx9bcSh6lxx0u4S0grMTuh7uPOnSFysoQsFC+2Sa+YzOLrNA2S1Nwkc735QM2puzMs+488Qsiicl7OrlZciALQ1o82uodxlBD1FQJvnQGXfbTjNEOpxi5xFzESiDFfC62sYkzV8GjWia2TJDZow4pK/OnBkPkwYu6DZ02hLgSS6MYHliMBF7z5uUNsv6PpKVgkyIz2ZxjR02U8Mx0IbISf8iK8k8uf3IptPwLk+Dc/nyX/yYTa8VrACx/owI+qflFA6DgpTaI4CCXOJSgFZSIg/6W1inWNxb5iciQpfS73xS9aJy4HDGoH3YuEhyYkkxP4Pd47xt/hUXcY+Z1cK7/7S7iAVKYLM5Wd/PoMHxoT71sfICqnUeszY5CLp4UY9ZrAvG5sORGXQJ8OTLJO1m+6mL7uWv43+daUcpioucr9qcMRJshwSEJdpBUn4VW5plaQzAzUUlE3YBI7szSJIFkCb6Fe/y+9P6UGHQ== dean@deanlofts.xyz
```

This ensures direct SSH access to the EC2 instance using this key.

---

## Tooling & Runtimes: Comparison

**On the AMI (EC2 Instance):**

- **OS Security & Monitoring:** `lynis`, `fail2ban`, `rkhunter`, `aide`
- **Base Tools:** `curl`, `wget`, `git`, `vim`, `nano`, `build-essential`, `python3-pip`
- **Runtimes:** Node.js (20), Go (1.22), Rust (latest), Ruby (3.3), Python (3.12)
- **Additional CLI Tools:** Bun, uv (installed via official script), fd, fzf, ripgrep, AWS CLI, ImageMagick, jq, yq, htop, ncdu, zip/unzip
- **Docker:** Installed via `curl -fsSL https://get.docker.com | sh`
- **EFS Utils:** `amazon-efs-utils` for mounting/unmounting EFS
- **ECR Login:** Scripts call `aws ecr get-login-password`
- **Scripts:**
  - `build.sh` / `buildx.sh`: Build and push Docker images to ECR.
  - `monitor.sh`: On-demand checks (CPU, disk, memory).
  - `connect.sh`: Easy SSH or SSM sessions.
  - `verify.sh`: Confirm all tools and runtimes installed.

**On the Docker Container (ECS):**

- **No OS Security Tools.**
- **Runtimes & Tools Pre-Installed in Image:** Same as AMI but sourced from official or community images including uv (pre-built into the Docker image).
- **No SSH:** Use ECS Exec (SSM) via `connect.sh` which runs `aws ecs execute-command`.
- **EFS on ECS:** If needed, mounted via ECS Task Definition configuration.
- **monitor.sh on ECS:** A simplified script for container-level checks. Accessible via ECS Exec.

`verify.sh` ensures consistency in tool availability across both AMI and ECS.

---

## AWS Services Integration

- **ECR:**  
  `buildx.sh` builds and pushes multi-arch images to ECR. ECS tasks pull images from ECR.
- **EFS, S3, RDS, ElastiCache:**
  - IAM roles manage access.
  - Security groups control network access.
  - EFS mounts on AMI and optional on ECS tasks.

---

## Access & Security

- **SSH (EC2 Only):**  
  Terraform creates `aws_key_pair` with the hard-coded public key.  
  Security Groups can initially allow inbound SSH from `0.0.0.0/0` for setup (not recommended long-term).

- **SSM Access:**  
  Both AMI and ECS support SSM.  
  `connect.sh` leverages `aws ssm start-session` (AMI) or `aws ecs execute-command` (ECS).

- **IAM & Networking:**  
  IAM roles grant least-privilege access to ECR, S3, RDS, ElastiCache, EFS.  
  VPC, subnet, and security groups defined via Terraform with minimal required permissions and ingress rules.

---

## Monitoring & Alerting

- **CloudWatch Agent (EC2):**  
  AMI collects CPU, memory, disk metrics, and sends them to CloudWatch.

- **ECS Logging:**  
  ECS tasks send logs to CloudWatch Logs.

- **CloudWatch Alarms:**  
  Configurable alarms trigger on CPU > 80%, memory > 80%, disk < 10%.  
  Alarms send notifications (e.g., SNS).

- **monitor.sh Scripts:**  
  AMI: Detailed system checks.  
  ECS: Container-level checks via ECS Exec.

---

## Maintenance & Updates

- **Rebuild AMI:**  
  Update packages, rerun setup to refresh runtimes (via `mise` or direct installs).

- **Update Docker Images (ECS):**  
  Use `buildx.sh` to produce multi-arch images, push to ECR, update ECS Task Definitions.

- **verify.sh:**  
  Run after updates to confirm tool availability and integrity.

---

## Directory Structure

```
ubuntu-box-2025/
├─ ec2-environment/
│  ├─ terraform/
│  │  ├─ variables.tf        # region, arch
│  │  ├─ outputs.tf
│  │  └─ main.tf             # Includes aws_key_pair with hard-coded SSH public key
│  ├─ scripts/
│  │  ├─ cloud-init.yml
│  │  ├─ verify.sh
│  │  ├─ monitor.sh
│  │  ├─ mount_efs.sh
│  │  └─ connect.sh
│  └─ docs/
│     ├─ SETUP.md
│     ├─ MONITORING.md
│     └─ SECURITY.md
│
├─ ecs-environment/
│  ├─ terraform/
│  │  ├─ variables.tf        # region, cluster settings
│  │  ├─ outputs.tf
│  ├─ docker/
│  │  ├─ Dockerfile          # Based on a Ubuntu 24.04 official image plus Node, Go, Rust, Ruby, Python, Bun, fd, fzf, ripgrep, AWS CLI, etc.
│  │  ├─ verify.sh
│  │  ├─ build.sh
│  │  ├─ buildx.sh
│  │  ├─ monitor.sh
│  │  └─ connect.sh
│  └─ docs/
│     ├─ SETUP.md
│     ├─ CONTAINERS.md
│     └─ MONITORING.md
│
└─ README.md                  # Guidance on choosing EC2 vs ECS deployment
```

---

## Implementation Notes

- **Mutually Exclusive Deployments:**  
  The Terraform in `ec2-environment` and `ecs-environment` directories should never be applied simultaneously.
- **SSH Key Already Included (EC2):**  
  The `aws_key_pair` resource uses the provided SSH public key to ensure seamless SSH access.

- **uv Installation:**

  - EC2: `setup.sh` uses the official uv installation script.
  - ECS: Dockerfile uses an official uv-enabled base image.

- **Docker Installation (EC2):**  
  Achieved via `curl -fsSL https://get.docker.com | sh` in `setup.sh`.

- **Runtimes & Tools:**  
  Confirmed by `verify.sh` to ensure consistency.

---

## Putting It All Together

1. **For AMI (EC2):**

   - Run Terraform in `ec2-environment/terraform/` with `region` and `arch` variables.
   - Terraform provisions an EC2 instance using the chosen AMI and configures the `aws_key_pair` with the hard-coded SSH key.
   - Run `setup.sh` (via user-data or manually) to install runtimes, Docker (via `get.docker.com`), uv (via official script), and security tools.
   - Use `verify.sh` to ensure environment integrity.
   - `connect.sh` for SSH or SSM access.
   - `monitor.sh` for on-demand checks.

2. **For ECS (Docker):**

   - Run Terraform in `ecs-environment/terraform/` to create an ECS cluster, task definitions, and services.
   - `buildx.sh` builds and pushes multi-arch images to ECR, including uv and other tools.
   - ECS tasks run containers that include all runtimes and tools except OS-level security utilities.
   - Use `connect.sh` with `aws ecs execute-command` for container-level access.
   - `monitor.sh` inside containers for runtime diagnostics.

3. **AWS Integrations:**  
   All code references IAM roles, security groups, VPCs, and services like ECR, EFS, RDS, ElastiCache. Confirm credentials and policies in Terraform code.

---

This design document should be given to the LLM so it can:

- Understand the entire architecture and workflow.
- Generate Terraform, shell scripts, Dockerfiles, and documentation.
- Implement the environment as specified, including the hard-coded SSH key, Docker installation method, and uv setup approach.
