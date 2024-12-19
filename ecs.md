# Migrating from Docker Compose to AWS ECS with Fargate

This guide explains how to move your existing Docker Compose setup into AWS ECS running on Fargate. It covers the entire lifecycle: building Docker images and pushing them to ECR, defining ECS Task Definitions and Services, integrating an Application Load Balancer (ALB), connecting to RDS Postgres and ElastiCache Redis, managing secrets via SSM Parameter Store, and using IAM roles for secure access. It also discusses ECS Exec for container debugging, multi-architecture image builds, Terraform automation, and recommended best practices.

---

## Key Technologies and Versions

- **Amazon RDS (PostgreSQL)**: Uses PostgreSQL `16.1`
- **Amazon ElastiCache (Redis)**: Uses Redis `7.2`
- **AWS ECS Fargate**: Uses platform version `1.5.0`
- **Terraform AWS Provider**: Uses version `5.80.0`
- **Nginx Docker Image**: Uses `nginx:1.25.2`
- **Ruby (Rails) Docker Image**: Uses `ruby:3.3.0` as a base

Keeping everything current ensures you benefit from the latest performance enhancements, security patches, and new features. Verify compatibility with your application before upgrading these components in production.

---

## ECR (Elastic Container Registry)

You will store your Docker images in ECR so that ECS can pull them for deployment.

**Example Terraform Configuration:**

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
2. Update your Dockerfile base images to use `ruby:3.3.0` and `nginx:1.25.2`.

3. Build and push a multi-architecture image:
   ```bash
   docker buildx create --use
   docker buildx build --platform linux/amd64,linux/arm64 -t <account_id>.dkr.ecr.ap-southeast-2.amazonaws.com/my-app:latest . --push
   ```

---

## IAM Roles and Permissions

IAM roles enable your ECS tasks to securely access AWS services without embedding sensitive credentials directly into your code or configurations.

### Example: Task Execution Role

Below is an example of an IAM role configured for ECS task execution:

```hcl
resource "aws_iam_role" "task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      },
    ]
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

### Purpose of This Role

This role is configured to enable the following capabilities for ECS tasks:

- **Pull container images from Amazon ECR**: Permissions allow fetching and authenticating container images required for deployment.
- **Send logs to CloudWatch Logs**: Grants tasks the ability to create log streams and publish log events, ensuring observability.
- **Retrieve secrets and configuration parameters**:
  - **SSM Parameter Store**: Permissions for `ssm:GetParameter` allow secure retrieval of application configurations stored in Parameter Store.
  - **AWS Secrets Manager**: Permissions for `secretsmanager:GetSecretValue` let tasks securely access sensitive data, such as API keys or database credentials, managed by Secrets Manager.

### How Secrets and Parameters Are Delivered to ECS Tasks

Once the IAM role is assigned to the ECS task execution role and the necessary permissions are granted:

1. **SSM Parameter Store Integration**:

   - In the ECS task definition, you can specify SSM parameters in the `secrets` block.
   - Example:
     ```hcl
     secrets = [
       {
         name      = "API_SECRET_KEY"
         valueFrom = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/my-secret-key"
       }
     ]
     ```
     During task execution, ECS automatically fetches the specified parameters using the `GetParameter` action.

2. **Secrets Manager Integration**:

   - Similarly, Secrets Manager secrets are defined in the ECS task definition `secrets` block.
   - Example:
     ```hcl
     secrets = [
       {
         name      = "DB_PASSWORD"
         valueFrom = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:my-db-password"
       }
     ]
     ```
     ECS retrieves the secret value securely at runtime using the `GetSecretValue` action.

3. **Runtime Availability**:
   - The retrieved secrets and parameters are injected into the container environment as environment variables, with the names specified in the `secrets` block.
   - Containers can access these values securely without hardcoding sensitive information.

This eliminates the need for hardcoding credentials or storing sensitive information in task definitions, ensuring secure, dynamic access during runtime.

By configuring IAM roles, SSM parameters, and Secrets Manager secrets together, ECS tasks maintain secure and efficient access to necessary resources.

## ECS Task Definitions

The ECS Task Definition specifies containers, resources, environment variables, ports, and secrets.

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

## RDS (Postgres)

Amazon RDS provides a managed PostgreSQL database. Using PostgreSQL 16.1 offers the latest features and optimizations. Ensure your application is compatible before upgrading.

**RDS Postgres Example:**

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

ElastiCache provides a managed Redis cluster. Version 7.2 includes performance and security improvements.

**Redis Example:**

```hcl
resource "aws_elasticache_replication_group" "myredis" {
  replication_group_id = "my-redis"
  description          = "Redis for my-app"
  engine               = "redis"
  engine_version       = "7.2"
  node_type            = "cache.t3.micro"
  number_cache_clusters = 1
  parameter_group_name = "default.redis7.2"
  subnet_group_name    = aws_elasticache_subnet_group.default.name
  security_group_ids   = [aws_security_group.redis_sg.id]
}
```

---

## ECS Service Configuration and Fargate Platform Version

When defining your ECS service, specify the latest Fargate platform version (`1.5.0`) to use new features and improvements.

**Example ECS Service with ALB:**

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
}
```

---

## ECS Exec

ECS Exec allows you to run commands inside containers without exposing extra ports.

**IAM Policy for ECS Exec:**

```hcl
resource "aws_iam_policy" "ecs_exec_policy" {
  name = "ecs-exec-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
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

Attach this policy to the role that initiates `execute-command`.

---

## SSM Parameter Store

Use SSM Parameter Store to securely store secrets, like API keys or database passwords, instead of hardcoding them in code.

**Parameter Example:**

```hcl
resource "aws_ssm_parameter" "api_secret_key" {
  name        = "/myapp/api_secret_key"
  type        = "SecureString"
  value       = var.api_secret_key
}
```

Refer to this parameter in your ECS task definition’s `secrets` block.

---

## Scripts and Automation

**Build and Push Script:**

```bash
#!/bin/bash
set -euo pipefail

REGION="ap-southeast-2"
REPO_NAME="my-app"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO_URI
docker buildx build --platform linux/amd64,linux/arm64 -t $REPO_URI:latest . --push
```

**Force New Deployment Script:**

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
SERVICE="my-service"

aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
```

**Monitor Service Events:**

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
SERVICE="my-service"

aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query "services[0].events" --output table
```

---

## Terraform AWS Provider Configuration

Ensure you use the latest Terraform AWS provider version:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.80.0"
    }
  }
  required_version = ">= 1.5.0"
}
```

---

## Best Practices

1. **Infrastructure as Code**:  
   Keep all resources defined in Terraform and store state remotely (e.g., S3 with DynamoDB locking).

2. **Secrets Management**:  
   Use SSM Parameter Store or Secrets Manager to keep secrets out of code and configuration files.

3. **Secure Networking**:  
   Run ECS tasks, RDS, and Redis in private subnets. Use security groups and ALBs for controlled inbound traffic.

4. **Scaling and Health Checks**:  
   Configure ALB health checks so only healthy tasks receive traffic. Use ECS autoscaling based on CPU/Memory usage or custom CloudWatch metrics.

5. **Observability and Debugging**:  
   Use CloudWatch for logs and metrics. Use ECS Exec for on-demand debugging inside containers.

6. **Version Upgrades and Testing**:  
   Test all version upgrades (Postgres 16.1, Redis 7.2, and Docker base images) in a staging environment before applying them to production. Review Terraform AWS provider release notes for any breaking changes.

---

By following these steps and guidelines, you can smoothly migrate from Docker Compose to a fully managed, scalable, and secure ECS Fargate environment, leveraging the latest AWS and Terraform features.
