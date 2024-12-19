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

## ECS Task Definitions

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

By following these steps, configurations, and best practices, you can confidently migrate from Docker Compose to a fully managed, scalable, secure, and SOC 2-aligned ECS Fargate environment. This guide ensures that all details, versions, credential actions, Terraform configurations, secrets management, and compliance measures are accurately represented and up-to-date.
