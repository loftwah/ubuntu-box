# Migrating from Docker Compose to AWS ECS with Fargate

This guide explains how to migrate from a Docker Compose setup to AWS ECS Fargate. It covers building and pushing Docker images to ECR, creating ECS Task Definitions and Services, integrating an ALB, connecting to RDS Postgres and ElastiCache Redis, managing secrets with SSM Parameter Store and Secrets Manager, using IAM roles for secure access, ECS Exec for debugging, multi-architecture image builds, Terraform automation, Cloudflare integration for HTTPS, SOC 2 considerations, and best practices. It also details a CI/CD pipeline using GitHub Actions with updated versions and session policies.

---

## Key Technologies and Versions

- **Amazon RDS (PostgreSQL)**: `16.1`
- **Amazon ElastiCache (Redis)**: `7.2`
- **AWS ECS Fargate**: Platform version `1.5.0`
- **Terraform AWS Provider**: `5.81.0` (updated to ensure current accuracy)
- **Nginx Docker Image**: `nginx:1.25.2`
- **Ruby (Rails) Docker Image**: `ruby:3.3.0`

Keep components current for performance, security, and new features. Test upgrades in a non-production environment first.

---

## Architecture Overview

**High-Level Setup:**

- **ECR**: Store built images for ECS.
- **ECS Fargate**: Run Rails, Sidekiq, and Nginx containers without managing servers.
- **ALB (Application Load Balancer)**: Terminate HTTPS (with ACM certificates) and forward traffic to ECS tasks.
- **RDS (Postgres)** and **ElastiCache (Redis)**: Fully managed database and caching services.
- **Secrets Management**: SSM Parameter Store for static secrets, Secrets Manager for dynamic/critical secrets.
- **IAM Roles**: Grant ECS tasks least-privilege access to AWS services.
- **Cloudflare Integration**: Use Cloudflare as DNS/CDN, Full (Strict) SSL mode to ensure end-to-end encryption.
- **SOC 2 Compliance**: Encryption in transit, secure secrets management, auditing (CloudTrail), least privilege.

---

## ECR (Elastic Container Registry)

[aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)

**Terraform Example:**

```hcl
resource "aws_ecr_repository" "my_app" {
  name = "my-app"
}
```

**Build and Push Steps:**

1. Authenticate Docker to ECR:
   ```bash
   aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.ap-southeast-2.amazonaws.com/my-app
   ```
2. Update Dockerfile base images to `ruby:3.3.0` and `nginx:1.25.2`.
3. Build and push multi-architecture image:
   ```bash
   docker buildx create --use
   docker buildx build --platform linux/amd64,linux/arm64 \
     -t <account_id>.dkr.ecr.ap-southeast-2.amazonaws.com/my-app:latest . --push
   ```

---

## IAM Roles and Permissions

[iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | [AWS managed policies for Amazon Elastic Container Service](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-iam-awsmanpol.html)

**Task Execution Role Example:**

```hcl
resource "aws_iam_role" "task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "ecs-task-logging"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "ssm:GetParameter",
            "secretsmanager:GetSecretValue"
          ],
          Effect   = "Allow",
          Resource = "*"
        }
      ]
    })
  }
}
```

**Purpose:**

- Pull images from ECR.
- Send logs to CloudWatch.
- Retrieve secrets from SSM and Secrets Manager.

This adheres to least privilege, a key SOC 2 principle.

---

## Secrets Management: SSM Parameter Store & Secrets Manager

[ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | [secretsmanager_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | [secretsmanager_secret_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)

**When to Use SSM Parameter Store:**

- Static configs (API keys without rotation needs)
- Cost-sensitive scenarios
- Hierarchical organization

**When to Use Secrets Manager:**

- Dynamic or critical secrets (e.g., DB passwords)
- Automatic rotation
- Detailed auditing

**SSM Parameter Example:**

```hcl
resource "aws_ssm_parameter" "api_secret_key" {
  name  = "/myapp/api_secret_key"
  type  = "SecureString"
  value = var.api_secret_key
}
```

**ECS Task Definition Using SSM:**

```hcl
secrets = [
  {
    name      = "API_SECRET_KEY"
    valueFrom = aws_ssm_parameter.api_secret_key.arn
  }
]
```

**Secrets Manager Example:**

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name = "my-db-password"
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}
```

**ECS Task Definition Using Secrets Manager:**

```hcl
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = aws_secretsmanager_secret.db_password.arn
  }
]
```

At runtime, ECS injects these secrets as environment variables, keeping sensitive data secure and compliant with SOC 2.

---

> **Note**: we could use 1password for this.

## ECS Task Definitions

[ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)

**Example:**

```hcl
resource "aws_ecs_task_definition" "my_app" {
  family                   = "my-app"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024

  container_definitions = jsonencode([
    {
      name      = "rails-app"
      image     = "${aws_ecr_repository.my_app.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true
      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.db_user}:${var.db_password}@${aws_db_instance.mydb.address}:5432/${var.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_replication_group.myredis.primary_endpoint_address}:6379"
        }
      ]
      secrets = [
        {
          name      = "API_SECRET_KEY"
          valueFrom = aws_ssm_parameter.api_secret_key.arn
        }
      ]
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    },
    {
      name      = "sidekiq-worker"
      image     = "${aws_ecr_repository.my_app.repository_url}:latest"
      memory    = 256
      cpu       = 128
      essential = false
    },
    {
      name      = "nginx"
      image     = "nginx:1.25.2"
      memory    = 128
      cpu       = 64
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}
```

---

## RDS (PostgreSQL)

[db_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)

**Example:**

```hcl
resource "aws_db_instance" "mydb" {
  allocated_storage     = 20
  max_allocated_storage = 100
  engine                = "postgres"
  engine_version        = "16.1"
  instance_class        = "db.t3.micro"
  db_name               = var.db_name
  username              = var.db_user
  password              = var.db_password
  parameter_group_name  = "default.postgres16"
  skip_final_snapshot   = true
  publicly_accessible   = false
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name  = aws_db_subnet_group.default.name
}
```

---

## ElastiCache (Redis)

[elasticache_replication_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group)

**Example:**

```hcl
resource "aws_elasticache_replication_group" "myredis" {
  replication_group_id  = "my-redis"
  description           = "Redis for my-app"
  engine                = "redis"
  engine_version        = "7.2"
  node_type             = "cache.t3.micro"
  number_cache_clusters = 1
  parameter_group_name  = "default.redis7.2"
  subnet_group_name     = aws_elasticache_subnet_group.default.name
  security_group_ids    = [aws_security_group.redis_sg.id]
}
```

---

## ECS Service and ALB Integration

[ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)

Use the latest Fargate platform version (`1.5.0`) and integrate with an ALB for load balancing and health checks.

**Example:**

```hcl
resource "aws_ecs_service" "my_app_service" {
  name             = "my-app-service"
  cluster          = aws_ecs_cluster.my_cluster.id
  task_definition  = aws_ecs_task_definition.my_app.arn
  desired_count    = 2
  launch_type      = "FARGATE"
  platform_version = "1.5.0"
  enable_execute_command = true

  network_configuration {
    subnets         = aws_subnet.private_subnets[*].id
    security_groups = [aws_security_group.service_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "nginx"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}
```

---

## HTTPS Termination and Cloudflare Integration

[lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)

- **ACM Certificate**: Obtain a valid SSL/TLS certificate via ACM for `loftwah.com` and `*.loftwah.com`.
- **Cloudflare**: Set to "Full (Strict)" mode. Cloudflare encrypts traffic to the ALB, ensuring SOC 2 compliance by encrypting in transit.
- **ALB HTTPS Listener**:

  ```hcl
  resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.my_lb.arn
    port              = 443
    protocol          = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
    certificate_arn   = aws_acm_certificate.my_cert.arn

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app_tg.arn
    }
  }
  ```

---

## ECS Exec

[iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)

ECS Exec allows in-container debugging without exposing SSH ports.

**IAM Policy:**

```hcl
resource "aws_iam_policy" "ecs_exec_policy" {
  name = "ecs-exec-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect  = "Allow",
        Action  = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      }
    ]
  })
}
```

---

## Terraform AWS Provider Configuration

[AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) | [Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

**Example:**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
  required_version = ">= 1.5.0"
}
```

Store Terraform state in S3 and use DynamoDB for state locking to ensure safe, collaborative changes.

---

## CI/CD Pipeline with GitHub Actions

This example shows how to use GitHub Actions to deploy AWS resources using Terraform. It uses OpenID Connect (OIDC) to obtain temporary AWS credentials at runtime, which means you do not need to store long-term AWS keys in GitHub.

**Before You Begin:**

1. **Create an IAM Role in AWS:**  
   You must create an IAM role in your AWS account that:

   - Trusts GitHub as an identity provider.
   - Grants the necessary permissions for Terraform to manage your infrastructure.  
     Once you have created this role, note its Amazon Resource Name (ARN), such as `arn:aws:iam::123456789012:role/MyDeployRole`.

2. **Configure OIDC Trust in AWS:**  
   Set up an Identity Provider in IAM using GitHub's OIDC endpoint. This tells AWS to trust GitHub Actions workflows from your repository.

3. **Update Your Workflow Permissions:**  
   In your GitHub Actions workflow file, you must grant `id-token: write` and `contents: read` permissions so that GitHub can request and provide the OIDC token to AWS.

**Tools Used:**

- `actions/checkout@v4`: Checks out your repository code.
- `aws-actions/configure-aws-credentials@v4`: Assumes the IAM role you created in AWS using OIDC, retrieving short-lived credentials.
- `hashicorp/setup-terraform@v3`: Installs the Terraform CLI so you can run `terraform` commands in your pipeline.

**Inline Session Policy (Optional):**

If you want to further restrict what the temporary credentials can do beyond what the IAM role allows, you can provide an inline session policy. This is optional. If you do not need this granularity, remove the policy. For example, if your Terraform configuration reads state from S3, you might limit the workflow to only list objects in S3, reducing the risk of unintended actions.

If you do not need S3 permissions or extra restrictions, simply remove this block.

**Example GitHub Actions Workflow:**

```yaml
name: Deploy
on:
  push:
    branches: ["main"]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # Step 1: Check out the repository
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # Step 2: Configure AWS credentials using the IAM role you created in AWS
      # Replace the ARN below with the ARN of the IAM role you created.
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ap-southeast-2
          role-to-assume: arn:aws:iam::123456789012:role/MyDeployRole
          inline-session-policy: >-
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Sid": "ListS3Only",
                  "Effect": "Allow",
                  "Action": "s3:List*",
                  "Resource": "*"
                }
              ]
            }

      # Step 3: Install Terraform (version 1.1.7 as recommended by the README)
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.1.7"

      # Step 4: Initialize Terraform to set up modules and providers
      - name: Terraform Init
        run: terraform init

      # Step 5: Apply Terraform configuration to manage AWS resources
      - name: Terraform Apply
        run: terraform apply -auto-approve
```

**What This Pipeline Does:**

1. **Checks out your code** so Terraform can read your configuration.
2. **Assumes your pre-created IAM role** using GitHub OIDC. You must have created this role and configured it in AWS beforehand. The pipeline does not create it for you.
3. **Optionally applies an inline session policy** to restrict permissions further. If you do not need this, remove it.
4. **Installs Terraform and runs your Terraform commands**. The Terraform CLI uses the temporary AWS credentials, so no hardcoded secrets are required.

## CI/CD with AWS CodeBuild and CodePipeline

If you prefer using AWS-native services for CI/CD, you can leverage AWS CodeBuild and CodePipeline instead of GitHub Actions. This approach keeps all CI/CD operations within your AWS account, which some teams prefer for compliance, cost, or integration reasons.

**High-Level Flow:**

1. **CodeCommit or GitHub Source**:  
   Store your infrastructure code in AWS CodeCommit or continue using GitHub as a source. If using GitHub, integrate it as a source stage in CodePipeline.

2. **CodePipeline**:  
   Set up a pipeline with stages like Source, Build, and Deploy. CodePipeline will:

   - Retrieve code from your chosen source (GitHub or CodeCommit).
   - Trigger a CodeBuild project to run Terraform commands.
   - Optionally, have a Deploy stage to apply Terraform changes or run additional scripts.

3. **CodeBuild**:  
   CodeBuild will run in a containerized environment and can execute Terraform commands. You:
   - Provide a buildspec.yml file that runs `terraform init` and `terraform apply`.
   - Use an IAM role attached to the CodeBuild project so that Terraform can access AWS resources (no need for OIDC here since CodeBuild runs inside your AWS environment).

**Example Buildspec for CodeBuild:**

```yaml
version: 0.2

phases:
  install:
    commands:
      - curl -o terraform.zip https://releases.hashicorp.com/terraform/1.1.7/terraform_1.1.7_linux_amd64.zip
      - unzip terraform.zip && mv terraform /usr/local/bin/
      - rm terraform.zip
  pre_build:
    commands:
      - terraform init
  build:
    commands:
      - terraform apply -auto-approve
artifacts:
  files:
    - "**/*"
```

**What This Does:**

1. **Source Stage (CodePipeline)**:  
   Pulls the latest commit from your GitHub repo or CodeCommit repository.

2. **Build Stage (CodePipeline with CodeBuild)**:  
   Launches a CodeBuild container that:
   - Installs Terraform (version 1.1.7 in this example).
   - Runs `terraform init` to prepare for deployment.
   - Runs `terraform apply -auto-approve` to provision or update resources.
3. **Deploy Stage (Optional)**:  
   If your infrastructure requires additional steps, CodePipeline can invoke more CodeBuild projects or Lambda functions.

**IAM Considerations for CodeBuild and CodePipeline:**

- Create and assign an IAM role to CodeBuild that grants the necessary permissions for Terraform to manage your AWS infrastructure.
- Since CodeBuild runs inside AWS, you do not need OIDC or external credential configuration as you do with GitHub Actions. The IAM role attached to CodeBuild determines what Terraform can do.

**When to Use CodeBuild/CodePipeline:**

- If you want an entirely AWS-native CI/CD process.
- If you prefer tight integration with AWS services and do not want to rely on GitHub Actions for your pipeline logic.
- If compliance or organizational policies require that build and deploy processes run within your AWS environment.

By using CodeBuild and CodePipeline, your Terraform CI/CD pipeline resides entirely inside AWS. You have no need for external tokens or roles outside AWS, as all credentials and permissions are managed natively through IAM roles assigned to your build and deploy stages.

## Observability and Monitoring

- **CloudWatch Logs and Metrics**: Central logging and monitoring.
- **CloudWatch Alarms**: Trigger alerts for high CPU usage, memory usage, or unhealthy tasks.
- **ALB Access Logs**: Store in S3 for auditing.
- **ECS Exec**: On-demand debugging inside containers.

---

## Scaling and Health Checks

- **ALB Health Checks**: Only route traffic to healthy tasks.
- **ECS Autoscaling**: Scale services up/down based on CPU, memory, or custom metrics.

**Example ECS Autoscaling:**

```hcl
resource "aws_appautoscaling_target" "ecs_scaling_target" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.my_app_service.name}"
  min_capacity       = 1
  max_capacity       = 10
}
```

---

## SOC 2 Compliance Considerations

- **Encryption in Transit**: HTTPS via ALB, Cloudflare Full (Strict) mode.
- **Encryption at Rest**: RDS, EBS, ElastiCache, and secrets encrypted with KMS.
- **Least Privilege IAM**: Inline session policies and narrowly scoped roles.
- **Auditing and Logging**: CloudTrail, CloudWatch logs, ALB logs, GitHub Actions logs.
- **Vendor Compliance**: AWS holds SOC 2, ISO, and PCI certifications, aiding compliance.

---

## Networking in ECS vs Docker Compose

When configuring services like **nginx** to communicate with an application backend (e.g., an `app` service) in **Docker Compose** or **Amazon ECS**, the networking behaviour differs significantly. Understanding these differences is crucial for a smooth migration or setup.

### Docker Compose Networking

In Docker Compose, each container runs in its own isolated network namespace. Communication between services is achieved via service names defined in the `docker-compose.yml` file, as Docker Compose automatically sets up an internal network with DNS resolution for service names. For example:

```yaml
services:
  app:
    build: ./app
    ports:
      - "8080:8080"
  nginx:
    build: ./nginx
    ports:
      - "80:80"
    depends_on:
      - app
```

In this setup:

- The `nginx` service cannot use `localhost:8080` to communicate with the `app` service because `localhost` refers to the `nginx` container itself.
- Instead, the `app` service must be referenced by its service name (`app:8080`) as defined in the Compose file.

#### Example nginx Configuration in Docker Compose

In the `nginx` configuration file, you would specify the backend service using its Compose service name, not `localhost`. For example:

```nginx
server {
    listen 80;

    location / {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Amazon ECS Networking

In Amazon ECS, the networking behaviour depends on the **network mode** and whether containers are running within the same **task definition**:

#### Containers in the Same ECS Task

When containers are part of the same task definition and launched using the **`awsvpc` network mode** (the most common mode for Fargate or EC2 launch types), they share the same network namespace. This means they can communicate with each other using `localhost`:

- `nginx` can reference the `app` service at `localhost:8080` because both containers share the same network interface.

#### Example nginx Configuration in ECS (Same Task)

In this case, you can use `localhost` in the `nginx` configuration file:

```nginx
server {
    listen 80;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### Containers in Separate ECS Tasks

If `nginx` and `app` are deployed in separate tasks:

- `localhost` will not work because each task runs in its own isolated network namespace.
- Communication must be established via an **external DNS name** or **ECS Service Discovery**.
- For example, `nginx` can reference `app` using its DNS name (e.g., `app.example.local:8080`) or via a load balancer (e.g., `app-alb.example.com`).

#### Example nginx Configuration in ECS (Separate Tasks)

For tasks running separately, you would configure `nginx` to use the DNS name or load balancer of the `app` service:

```nginx
server {
    listen 80;

    location / {
        proxy_pass http://app.example.local:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Managing Multiple nginx Configurations

In scenarios where your deployment environments differ significantly (e.g., Docker Compose vs ECS), maintaining separate nginx configuration files, such as `nginx.conf.local` for Docker Compose and `nginx.conf.ecs` for ECS, is one approach. However, there are other, more streamlined methods to manage this:

1. **Environment-Specific Variables**:
   Use environment variables to dynamically set the backend address in the nginx configuration:

   ```nginx
   server {
       listen 80;

       location / {
           proxy_pass http://$BACKEND_HOST:$BACKEND_PORT;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

   Then pass the appropriate values for `BACKEND_HOST` and `BACKEND_PORT` when running the container.

   - For Docker Compose:

     ```yaml
     environment:
       BACKEND_HOST: app
       BACKEND_PORT: 8080
     ```

   - For ECS, use task definition environment variables or secrets to set these values.

2. **Single Config with Conditional Logic**:
   Use templating tools like [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html) to generate the final configuration at runtime. For example:

   ```bash
   envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
   ```

   This allows you to maintain a single `nginx.conf.template` file that uses placeholders for dynamic values.

   Note: The official nginx image does not include `envsubst` by default. To use it, you must create a custom image based on `nginx` that includes the required tools. Example Dockerfile:

   ```dockerfile
   FROM nginx:latest
   RUN apt-get update && apt-get install -y gettext-base && rm -rf /var/lib/apt/lists/*
   ```

3. **Centralised Configuration Management**:
   Use a configuration management tool like AWS Systems Manager Parameter Store or HashiCorp Consul to fetch the backend configuration dynamically. For example, you can configure nginx to resolve the backend address from a service discovery endpoint.

4. **Docker Multi-Stage Builds**:
   Include both configurations in your Docker image and copy the appropriate one based on a build argument or runtime environment variable:
   ```dockerfile
   ARG ENV
   COPY nginx.conf.$ENV /etc/nginx/nginx.conf
   ```
   Then build or run with `--build-arg ENV=local` or `--build-arg ENV=ecs`.

### Limitations of the Official nginx Image

The official nginx Docker image is lightweight and does not include additional tools like `envsubst` or scripting utilities by default. This limits its flexibility for dynamic configuration:

- **File Mounts**: You can mount configuration files into the container, but you must prepare the appropriate file beforehand, as the image does not support on-the-fly configuration generation.
- **Environment Variables**: Direct usage of environment variables within the nginx configuration file is not supported without additional tools (e.g., `envsubst`).

To overcome these limitations, consider:

- Building a custom nginx image with the necessary tools installed (e.g., `gettext` for `envsubst`).
- Using external tools or scripts during container startup to preprocess the nginx configuration file.
- Transitioning to templating solutions or centralised configuration management.

### Key Differences

| Feature               | Docker Compose                              | Amazon ECS                                   |
| --------------------- | ------------------------------------------- | -------------------------------------------- |
| **Network Isolation** | Containers isolated by default              | Containers share namespace within a task     |
| **Localhost Usage**   | Not valid for cross-container communication | Valid within the same task                   |
| **Service Discovery** | Service name resolution (e.g., `app:8080`)  | DNS name or load balancer for separate tasks |

### Example Use Case: nginx and app

- **Docker Compose**: Configure nginx to use `app:8080` in its reverse proxy configuration.
- **ECS (Same Task)**: Configure nginx to use `localhost:8080` for the app.
- **ECS (Separate Tasks)**: Use ECS Service Discovery or an ALB to resolve the app’s DNS name, e.g., `app.example.local:8080`.

By adapting the network configuration based on the environment, you ensure reliable communication between services in both Docker Compose and ECS setups.

---

## Local Development Workflow: Simulating ECS-Like Environments

When working with AWS ECS Fargate, you need a local setup that mirrors the ECS environment for testing and debugging. Using **docker compose**, you can replicate ECS-like behavior, enabling faster iterations and more reliable testing before deployment. Here’s how to set up and optimize your local development workflow.

---

Yes, let me write a new version that incorporates the gotchas and practical considerations while maintaining the same structure:

### Leveraging `docker-compose.override.yml`

The `docker-compose.override.yml` file provides a powerful but sometimes tricky way to customize your local development environment. Docker Compose automatically detects and merges this file with your base `docker-compose.yml` without requiring any flags. While this automatic behavior makes it perfect for development configurations, it can also lead to confusion if you're not aware of how the override system works.

#### Base `docker-compose.yml`

```yaml
name: myapp

services:
  app:
    image: your-ecr-repo-url:latest
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    ports:
      - "8080:3000"
    environment:
      DATABASE_URL: "postgres://user:password@db:5432/app"
      REDIS_URL: "redis://redis:6379"
      RAILS_ENV: production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s # Add this
      retries: 3
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  db:
    image: postgres:16.1
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: app
    volumes:
      - db_data:/var/lib/postgresql/data

  redis:
    image: redis:7.2

volumes:
  db_data:
```

#### Local `docker-compose.override.yml`

```yaml
name: myapp

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.local
      target: development
    environment:
      DATABASE_URL: "postgres://localhost:5432/app"
      REDIS_URL: "redis://localhost:6379"
      RAILS_ENV: development
    volumes:
      - .:/app
      - bundle:/usr/local/bundle # Add this
    ports:
      - "3000:3000"
      - "1234:1234" # Debugging
    command: ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  db:
    ports:
      - "5432:5432"

  redis:
    ports:
      - "6379:6379"

volumes:
  db_data:
  bundle: # Add this to volumes section
```

When working with these files, there are several important things to understand. The automatic merging can sometimes hide what configuration is actually running. To see the final, merged configuration that Docker Compose will use, run `docker compose config`. This is especially useful when joining a project or debugging unexpected behavior.

Since `docker-compose.override.yml` is typically gitignored, you might see a `docker-compose.override.yml.example` file in repositories. This example file shows the expected local development settings that you can copy and customize. If you're experiencing unexpected behavior, remember that you can bypass the override file entirely by explicitly specifying just the base file: `docker compose -f docker-compose.yml up`.

Environment variables add another layer of complexity, as they can affect both files. When troubleshooting, use `docker compose config` to verify the final values. Additionally, be aware that CI/CD pipelines might behave differently than local development if they're not explicitly configured to handle override files.

### Practices for Simulating ECS Locally

#### 1. Use `.env` for Configuration

Manage environment variables through `.env` files. This keeps configurations clean and portable.

**Example `.env.development`**

```dotenv
DATABASE_URL=postgres://localhost:5432/app
REDIS_URL=redis://localhost:6379
RAILS_ENV=development
```

---

#### 2. A Development-Ready Dockerfile

Streamline your builds with a multi-stage Dockerfile. Add debugging tools for a better local development experience.

```dockerfile
# Dockerfile.local
FROM ruby:3.3.0-slim as base

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential libpq-dev nodejs

# Development stage
FROM base as development
RUN apt-get install -y postgresql-client vim ruby-debug-ide  # Add debugging tools
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# Production stage
FROM base as production
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test
COPY . .
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

---

#### 3. Mocking AWS Services with LocalStack

Simulate AWS services locally for better integration testing.

**docker compose setup**

```yaml
localstack:
  image: localstack/localstack
  environment:
    - SERVICES=s3,secretsmanager
    - AWS_DEFAULT_REGION=ap-southeast-2
  ports:
    - "4566:4566"
```

**Ruby LocalStack Configuration**

```ruby
Aws.config.update(
  endpoint: ENV.fetch("AWS_ENDPOINT_URL", "http://localhost:4566"),
  region: "ap-southeast-2",
  credentials: Aws::Credentials.new("test", "test")
)
```

---

### Debugging with `docker compose exec`

**Example Workflow:**

1. Start the environment:

   ```bash
   docker compose up --build
   ```

2. Interact with the application:

   ```bash
   docker compose exec app bundle exec rails console
   ```

3. Inspect services:

   ```bash
   docker compose exec app /bin/bash
   ```

4. Tear down everything:
   ```bash
   docker compose down -v
   ```

---

### BuildKit Note

For better caching and multi-stage builds, enable BuildKit:

```bash
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker compose build
```

---

## Best Practices

1. **Infrastructure as Code**:  
   Use Terraform for all resources. Store state in S3 with DynamoDB locks.
2. **Secrets Management**:  
   Keep secrets out of code. Use SSM or Secrets Manager and reference in ECS tasks.
3. **Secure Networking**:  
   Run ECS tasks, databases, and caches in private subnets. Restrict ingress via SGs and ALB.
4. **Scaling and Health Checks**:  
   Implement ALB health checks and ECS autoscaling for high availability and efficiency.
5. **Observability and Debugging**:  
   Use CloudWatch, ECS Exec, and logs to troubleshoot and ensure performance and stability.
6. **Version Upgrades and Testing**:  
   Test Postgres 16.1, Redis 7.2, Nginx 1.25.2, and Ruby 3.3.0 in staging first.
7. **CI/CD**:  
   Automate deployments with GitHub Actions, using `actions/checkout@v4` and `aws-actions/configure-aws-credentials@v4` for secure credential management.
8. **SOC 2 Alignment**:  
   Encrypt data, enforce least privilege, audit changes, and maintain operational excellence.

---

Here’s a structured **## References** section for your document, including the resource types and their links to the Terraform AWS Provider documentation:

---

## References and Considerations

This section provides a comprehensive list of Terraform resources used in the infrastructure. Each resource is documented with its purpose, required and optional configurations, and their implications in the larger system. Understanding these resources and their relationships is crucial for building a robust ECS infrastructure.

---

### Elastic Container Registry (ECR)

#### [aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)

- **Purpose**: Serves as your private container registry, storing and managing Docker images that your ECS tasks will use. This resource is fundamental to your container infrastructure as it provides a secure, scalable way to distribute your application images.

**Required**:

- **Name**: Forms your repository's unique identifier and becomes part of your image URI. The name you choose affects how you'll reference images in task definitions and CI/CD pipelines. Consider a hierarchical naming scheme like `${org}-${app}-${component}` (e.g., `acme-web-api`) for clarity and organization.

**Optional**:

- **Image Tag Mutability**: A critical security and deployment control:
  - `MUTABLE`: Enables overwriting tags, simplifying development but risking deployment inconsistency.
  - `IMMUTABLE`: Prevents tag overwriting, ensuring deployment reliability and audit compliance.
- **Image Scanning**: Automates vulnerability detection in your container images. The enablement decision impacts your security posture and deployment pipeline speed.
- **Lifecycle Policies**: Manages repository growth and cost through automated cleanup rules. Consider retention requirements for rollbacks and compliance when configuring.

**Resource Relationships**:

- ECS task definitions depend on this for image references
- CI/CD pipelines need push access through IAM roles
- VPC endpoints may be required for private image pulls

---

### Elastic Container Service (ECS)

#### [aws_ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)

- **Purpose**: Functions as your container orchestration platform's control plane, managing the placement, scheduling, and operation of your containers. This is the foundation upon which all your containerized applications will run.

**Required**:

- **Name**: Identifies your cluster uniquely within your AWS account. Choose a name that reflects its environment and purpose, such as `${org}-${env}-cluster` (e.g., `acme-prod-cluster`), as this name appears in logs and metrics.

**Optional**:

- **Capacity Providers**: Determines the underlying compute platform:
  - `FARGATE`: Offers serverless operation with per-second billing, ideal for variable workloads.
  - `EC2`: Provides more control and potential cost savings for predictable workloads.
- **Container Insights**: Enables detailed monitoring and metrics collection. The cost impact (roughly $2.50 per day per cluster) should be weighed against observability needs.
- **Execute Command**: Enables interactive debugging capabilities, crucial for troubleshooting but requires careful security consideration.

**Resource Relationships**:

- Services and tasks run within the cluster context
- Capacity providers affect networking and scaling behavior
- CloudWatch receives metrics and logs from the cluster

#### [aws_ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)

- **Purpose**: Manages the deployment and maintenance of your containerized applications, ensuring the desired number of tasks remain healthy and available. This resource handles the operational aspects of your containers.

**Required**:

- **Cluster**: References the ECS cluster where this service will run. The choice of cluster affects resource availability and networking options.
- **Task Definition**: Specifies the container configuration to deploy. This is your application's blueprint.
- **Desired Count**: Determines how many copies of your task should run simultaneously. Consider high availability needs and cost implications.

**Optional**:

- **Load Balancer**: Enables traffic distribution across tasks. Essential for web applications:
  - Impacts how your application receives traffic
  - Affects service discovery options
  - Influences scaling behavior
- **Auto Scaling**: Automatically adjusts task count based on metrics:
  - CPU and memory utilization
  - Custom metrics
  - Schedule-based scaling
- **Deployment Configuration**: Controls how updates roll out:
  - Rolling updates
  - Blue/green deployments
  - Circuit breaker settings

**Resource Relationships**:

- Depends on ECS cluster and task definitions
- Integrates with load balancers and target groups
- Uses IAM roles for task execution
- May require service discovery configuration

#### [aws_ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)

- **Purpose**: Defines the complete specification for running your containers, including resource requirements, networking, storage, and security settings. This is your application's contract with ECS.

**Required**:

- **Container Definitions**: The core specification of your application:
  - Image: References your ECR repository
  - CPU/Memory: Resource allocations
  - Port mappings: Network exposure
  - Environment variables: Configuration
  - These decisions directly impact application performance and cost
- **Execution Role**: Grants ECS permission to:
  - Pull container images
  - Send logs to CloudWatch
  - Access secrets
    Without proper permissions, tasks cannot start

**Optional**:

- **Task Role**: Grants containers permission to access AWS services:
  - Consider least privilege principles
  - Separate roles for different services
- **Network Mode**: Determines container networking:
  - `awsvpc`: Required for Fargate, provides ENI per task
  - `bridge`: Traditional Docker networking
  - `host`: Direct host network access
- **Volumes**: Enables persistent storage:
  - EFS for shared filesystem access
  - Bind mounts for local storage
  - Consider data persistence needs
- **Secrets**: Securely injects sensitive data:
  - Secrets Manager for credentials
  - SSM Parameters for configuration
  - Affects security posture and maintenance

**Resource Relationships**:

- References ECR repositories for images
- Uses IAM roles for permissions
- Integrates with EFS for storage
- Connects to CloudWatch for logging

---

### Elastic File System (EFS)

#### [aws_efs_file_system](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system)

- **Purpose**: Provides scalable, persistent storage that can be shared across multiple ECS tasks and availability zones. Essential for applications requiring shared state or persistent data.

**Required**:

- **Creation Token**: Ensures idempotent filesystem creation. Use a meaningful identifier that reflects the filesystem's purpose.

**Optional**:

- **Encrypted**: Controls data-at-rest encryption:
  - Should generally be enabled for production
  - Can use custom KMS keys
  - Impacts performance minimally
- **Performance Mode**: Balances performance characteristics:
  - `generalPurpose`: Default, good for most workloads
  - `maxIO`: Higher latency but better for parallel access
- **Throughput Mode**: Controls filesystem performance:
  - `bursting`: Good for variable workloads
  - `provisioned`: Predictable performance at higher cost
- **Lifecycle Policy**: Manages cost for infrequently accessed data

**Resource Relationships**:

- Mount targets connect to VPC subnets
- Security groups control access
- Access points provide application-specific entry points

#### [aws_efs_access_point](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point)

- **Purpose**: Creates application-specific entry points to your EFS filesystem, enforcing file system isolation and access control between different applications sharing the same filesystem.

**Optional**:

- **Root Directory**: Controls filesystem visibility:
  - Path to expose to applications
  - Creation settings for new directories
- **POSIX User**: Enforces access permissions:
  - UID/GID mapping
  - File ownership controls
- **Tags**: Organize and track access points

**Resource Relationships**:

- Connects to EFS filesystem
- Referenced in ECS task definitions
- May require security group rules

#### [aws_efs_mount_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target)

- **Purpose**: Creates network interfaces that allow ECS tasks to connect to your EFS filesystem from within their VPC subnets. Without mount targets, your filesystem is inaccessible.

**Required**:

- **File System ID**: Links to your EFS filesystem. Each filesystem needs at least one mount target to be useful.
- **Subnet ID**: Places the mount target in your VPC. Deploy in each AZ where your tasks might run.
- **Security Groups**: Control network access to the filesystem.

**Resource Relationships**:

- Depends on EFS filesystem
- Requires VPC subnet placement
- Security groups must allow NFS traffic

---

### CloudWatch Logs

#### [aws_cloudwatch_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)

- **Purpose**: Centralizes log collection and retention for your ECS tasks, enabling monitoring, troubleshooting, and compliance needs. This is your primary window into application behavior.

**Required**:

- **Name**: Creates the logical container for your logs. Use a structured naming scheme like `/ecs/${app-name}/${environment}` for easy identification and management.

**Optional**:

- **Retention in Days**: Controls log lifetime:
  - Balance storage costs with compliance needs
  - Common values: 30, 60, 90 days
  - Infinite retention possible but expensive
- **KMS Encryption**: Protects sensitive log data
- **Export to S3**: Enables long-term archival
- **Metric Filters**: Creates metrics from log patterns

**Resource Relationships**:

- ECS tasks send logs here
- IAM roles need log writing permissions
- May integrate with external log aggregation

---

### Application Load Balancer (ALB)

#### [aws_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)

- **Purpose**: Distributes incoming application traffic across your ECS tasks, providing a single entry point while enabling high availability and scalability. Essential for web applications.

**Required**:

- **Name**: Identifies your load balancer. Choose a name that reflects its role and environment.
- **Subnets**: Places the ALB in your VPC:
  - Public subnets for internet-facing applications
  - Private subnets for internal services
- **Security Groups**: Control traffic access

**Optional**:

- **Internal**: Determines visibility:
  - `true` for internal services
  - `false` for internet-facing applications
- **Access Logs**: Enables request tracking:
  - S3 bucket for storage
  - Retention settings
  - Cost implications
- **Deletion Protection**: Prevents accidental removal

**Resource Relationships**:

- Target groups define backend services
- Listeners configure traffic handling
- Security groups control access
- Route 53 for DNS integration

#### [aws_lb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)

- **Purpose**: Defines how the load balancer checks health and routes traffic to your ECS tasks. This resource bridges the gap between your load balancer and containers.

**Required**:

- **Target Type**: Must be 'ip' for Fargate tasks
- **VPC ID**: Places the target group in your VPC
- **Protocol/Port**: Defines how traffic reaches containers
- **Health Check**: Ensures container availability:
  - Path to check
  - Success criteria
  - Check frequency

**Optional**:

- **Stickiness**: Maintains user sessions:
  - Cookie-based persistence
  - Duration settings
- **Deregistration Delay**: Allows in-flight requests:
  - Grace period for shutdowns
  - Impact on deployments
- **Load Balancing Algorithm**: Traffic distribution method

**Resource Relationships**:

- Referenced by ECS services
- Used by ALB listeners
- May require security group rules

#### [aws_lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)

- **Purpose**: Configures how your load balancer accepts and processes incoming traffic, defining the entry points for your application.

**Required**:

- **Load Balancer ARN**: Links to your ALB
- **Port**: Defines the listening port:
  - 80 for HTTP
  - 443 for HTTPS
- **Protocol**: Matches the port:
  - HTTP/HTTPS most common
  - TCP/TLS for lower-level protocols
- **Default Action**: Handles unmatched requests:
  - Forward to target group
  - Return fixed response
  - Redirect

**Optional**:

- **SSL Certificate**: Required for HTTPS:
  - ACM certificate reference
  - Multiple certificates possible
- **SSL Policy**: Security configuration:
  - Protocol versions
  - Cipher suites
- **Rules**: Advanced routing:
  - Path-based routing
  - Host-based routing
  - Query string conditions

**Resource Relationships**:

- Belongs to a load balancer
- References target groups
- May use ACM certificates
- Can trigger Lambda functions

---

### Identity and Access Management (IAM)

#### [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)

- **Purpose**: Defines permissions that AWS services (like ECS) can assume to interact with other AWS resources. Critical for security and access control.

**Required**:

- **Name**: Uniquely identifies the role:
  - Use descriptive names like `ecs-task-execution-role`
  - Include purpose and environment
- **Assume Role Policy**: Specifies who can use the role:
  - JSON policy document
  - Typically allows ECS service

**Optional**:

- **Description**: Documents the role's purpose
- **Path**: Organizes roles hierarchically
- **Force Detach Policies**: Handles cleanup
- **Max Session Duration**: Controls temporary credentials
- **Permissions Boundary**: Limits maximum permissions

**Resource Relationships**:

- Used by ECS tasks and services
- Attached to task definitions
- Referenced in service configurations

#### [aws_iam_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)

- **Purpose**: Defines custom permissions for your IAM roles when AWS managed policies don't provide the exact permissions needed.

**Required**:

- **Role**: References the IAM role
- **Policy**: JSON document defining:
  - Allowed actions
  - Resource restrictions
  - Conditions for access

**Optional**:

- **Name**: Identifies the policy
- **Name Prefix**: Generates unique names
- **Description**: Documents purpose

**Resource Relationships**:

- Attached to IAM roles
- Defines service permissions
- May reference various AWS resources

#### [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)

- **Purpose**: Attaches AWS managed policies to your roles, providing standardized permissions sets that AWS maintains.

**Required**:

- **Role**: The receiving role
- **Policy ARN**: The managed policy to attach:
  - AWSECSTaskExecutionRolePolicy
  - AWSECSServiceRolePolicy
  - Custom policy ARNs

**Resource Relationships**:

- Connects roles to policies
- Referenced by ECS services
- Part of task execution roles

---

### Security Groups

#### [aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)

- **Purpose**: Controls inbound and outbound network traffic for your AWS resources, acting as a virtual firewall at the instance level. Critical for securing your ECS infrastructure.

**Required**:

- **VPC ID**: Places the security group in your VPC. This association cannot be changed after creation, so choose carefully based on your network architecture.
- **Name**: Identifies the group uniquely within your VPC. Consider a naming convention like `${component}-${env}-sg` (e.g., `ecs-tasks-prod-sg`) for clear identification.

**Optional**:

- **Description**: Documents the group's purpose and rules. crucial for team understanding and compliance.
- **Tags**: Enable resource organization and cost tracking.
- **Ingress Rules**: Define allowed inbound traffic (though better managed through separate rules).
- **Egress Rules**: Specify allowed outbound traffic (though better managed through separate rules).

**Resource Relationships**:

- Used by ECS tasks, ALBs, and EFS mount targets
- Referenced in service definitions
- Interacts with other security groups through rules
- Must align with VPC CIDR ranges

#### [aws_security_group_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)

- **Purpose**: Defines specific inbound or outbound traffic rules for security groups. Separating rules from group definitions improves maintainability and reduces conflicts in team environments.

**Required**:

- **Type**: Specifies `ingress` (inbound) or `egress` (outbound). This fundamentally defines the rule's purpose.
- **Security Group ID**: Links to the security group this rule modifies.
- **Protocol**: Specifies allowed protocols (e.g., tcp, udp, icmp).
- **From Port** and **To Port**: Define the port range for the rule.
- **Source/Destination**: Determines allowed traffic sources/destinations through CIDR blocks or security group IDs.

**Optional**:

- **Description**: Documents the rule's specific purpose.
- **Self**: Allows references to the security group itself.
- **Prefix List IDs**: References AWS-managed prefix lists.

**Resource Relationships**:

- Belongs to specific security groups
- May reference other security groups
- Impacts network accessibility of resources
- Must align with application requirements

---

### VPC Endpoints

#### [aws_vpc_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)

- **Purpose**: Enables private communication between your VPC and AWS services without traversing the public internet. Essential for secure and reliable service access in private subnets.

**Required**:

- **VPC ID**: Associates the endpoint with your VPC. This defines the network context for private access.
- **Service Name**: Specifies which AWS service to connect to (e.g., `com.amazonaws.region.ecr.api`). The choice depends on which AWS services your applications need to access privately.

**Optional**:

- **VPC Endpoint Type**: Determines the endpoint's behavior:
  - `Interface`: Creates an ENI with a private IP
  - `Gateway`: Uses route tables for S3 and DynamoDB
- **Subnet IDs**: Required for interface endpoints, determines availability.
- **Security Group IDs**: Controls access to interface endpoints.
- **Private DNS**: Enables use of default AWS service DNS names.
- **Policy**: Restricts what actions can be performed through the endpoint.

**Resource Relationships**:

- Integrates with VPC networking
- Supports ECS service communication
- May require security group configurations
- Affects service DNS resolution

---

### ACM Certificate

#### [aws_acm_certificate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/acm_certificate)

- **Purpose**: Manages SSL/TLS certificates for securing application traffic. Essential for any public-facing applications requiring HTTPS.

**Required**:

- **Domain Name**: Specifies the domain to secure (e.g., `*.example.com`). Must match your application's domain name requirements.

**Optional**:

- **Validation Method**: Controls how certificate ownership is verified:
  - `DNS`: Automated validation through Route 53 or manual DNS records
  - `EMAIL`: Traditional email-based validation
- **Subject Alternative Names**: Adds additional domain names to the certificate
- **Tags**: Organizes and tracks certificates

**Resource Relationships**:

- Used by ALB listeners for HTTPS
- May integrate with Route 53 for DNS validation
- Referenced in listener configurations
- Affects application security posture

---

### Secrets Management

#### [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter)

- **Purpose**: Stores configuration values and non-sensitive secrets. Ideal for environment-specific settings and application configuration.

**Required**:

- **Name**: Creates a unique identifier, typically using hierarchical paths like `/app/${env}/${component}/${param}`.
- **Type**: Defines the parameter type:
  - `String`: Basic text values
  - `StringList`: Comma-separated values
  - `SecureString`: Encrypted values
- **Value**: The actual parameter value to store.

**Optional**:

- **Description**: Documents the parameter's purpose and usage.
- **KMS Key ID**: For custom encryption of SecureString parameters.
- **Tier**: Determines parameter capabilities and cost:
  - `Standard`: Free, basic parameters
  - `Advanced`: Larger values, higher cost
- **Tags**: Enables organization and tracking.

**Resource Relationships**:

- Referenced in ECS task definitions
- Used for application configuration
- May require IAM permissions for access
- Can integrate with KMS for encryption

#### [aws_secretsmanager_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)

- **Purpose**: Manages sensitive information like credentials, API keys, and other secrets. Provides additional features beyond SSM Parameter Store.

**Required**:

- **Name**: Uniquely identifies the secret. Use a descriptive naming scheme like `${app}/${env}/${purpose}`.

**Optional**:

- **Description**: Documents the secret's purpose and contents.
- **KMS Key ID**: Specifies a custom encryption key.
- **Policy**: Controls access through IAM policies.
- **Recovery Window**: Sets deletion grace period.
- **Rotation**: Configures automatic secret rotation:
  - Lambda function
  - Rotation schedule
  - Rotation rules

**Resource Relationships**:

- Referenced in task definitions
- May use KMS for encryption
- Requires IAM permissions for access
- Can trigger Lambda functions

#### [aws_secretsmanager_secret_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)

- **Purpose**: Manages different versions of secrets, enabling secret rotation and providing rollback capabilities.

**Required**:

- **Secret ID**: References the parent secret this version belongs to.
- **Secret String**: Contains the sensitive value to store.

**Optional**:

- **Version Stages**: Labels versions for different purposes:
  - `AWSCURRENT`: Active version
  - `AWSPENDING`: Next version
  - `AWSPREVIOUS`: Last active version
- **Version ID**: Automatically generated unique identifier.

**Resource Relationships**:

- Belongs to a Secrets Manager secret
- Referenced in applications
- Part of secret rotation workflow
- May require specific IAM permissions

---

By following these steps, configurations, and best practices, you can confidently migrate from Docker Compose to a fully managed, scalable, secure, and SOC 2-aligned ECS Fargate environment. This guide ensures that all details, versions, credential actions, Terraform configurations, secrets management, and compliance measures are accurately represented and up-to-date.

## Todo

Areas that could be enhanced:

1. **Cost Optimization**:

   - Auto-scaling policies and thresholds
   - Spot instances for non-critical workloads
   - Cost comparison between different instance types
   - Reserved capacity planning

2. **Disaster Recovery**:

   - Backup strategies
   - Multi-region deployment considerations
   - Recovery Time Objective (RTO) and Recovery Point Objective (RPO) guidelines
   - Failover procedures

3. **Monitoring & Alerting**:

   - CloudWatch dashboard examples
   - Common alert thresholds
   - APM integration (New Relic, Datadog)
   - Log aggregation strategies

4. **Performance Optimization**:

   - Container optimization techniques
   - Cache strategies
   - ECS capacity provider strategies
   - Performance testing methodologies

5. **Migration Strategies**:

   - Blue-green deployment details
   - Canary deployment patterns
   - Database migration handling
   - Zero-downtime deployment strategies

6. **Service Mesh Integration**:

   - AWS App Mesh configuration
   - Service discovery patterns
   - Inter-service communication

7. **Security Hardening**:

   - Container image scanning
   - Runtime security monitoring
   - Network policy examples
   - Security incident response procedures

Additional suggestions:

1. Include a troubleshooting section with common issues and solutions
2. Add example application architectures for different use cases
3. Provide maintenance and upgrade procedures
4. Include capacity planning guidelines
5. Add more real-world examples of scaling patterns

---
