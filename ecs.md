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

Use GitHub Actions for automated deployments. Updated versions:

- `actions/checkout@v4`
- `aws-actions/configure-aws-credentials@v4`

**Key Environment Variables:**

- After `configure-aws-credentials` runs, it sets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` as environment variables. It also sets `AWS_REGION` (or `AWS_DEFAULT_REGION`). These are available to subsequent steps like `terraform apply`, ensuring secure and temporary credentials without hardcoding.

**Inline Session Policies:**

- With `aws-actions/configure-aws-credentials@v4`, you can apply an inline session policy to limit scope:

  ```yaml
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/MyRole
    inline-session-policy: >-
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid":"Stmt1",
            "Effect":"Allow",
            "Action":"s3:List*",
            "Resource":"*"
          }
        ]
      }
  ```

This grants only the listed actions (e.g., `s3:List*`) during the session, improving security and SOC 2 alignment.

**Example GitHub Actions Workflow:**

```yaml
name: Deploy
on:
  push:
    branches: ["main"]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Ensures full history if needed

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/MyDeployRole
          aws-region: ap-southeast-2
          inline-session-policy: >-
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Sid": "Stmt1",
                  "Effect": "Allow",
                  "Action": "s3:List*",
                  "Resource": "*"
                }
              ]
            }

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve
```

This pipeline:

- Checks out the code using `actions/checkout@v4`.
- Configures AWS credentials with `aws-actions/configure-aws-credentials@v4`, setting secure environment variables and applying an inline session policy for limited permissions.
- Runs Terraform commands using the temporary credentials from the action.

---

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

By following these steps, configurations, and best practices, you can confidently migrate from Docker Compose to a fully managed, scalable, secure, and SOC 2-aligned ECS Fargate environment. This guide ensures that all details—versions, credential actions, Terraform configurations, secrets management, and compliance measures—are accurately represented and up-to-date.
