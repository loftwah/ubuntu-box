# Migrating from Docker Compose to AWS ECS with Fargate Using Terraform

This guide explains how to migrate a `docker-compose.yml` setup to AWS ECS with Fargate, incorporating key AWS features like Application Load Balancers (ALB), ECR repositories, IAM roles, RDS Postgres, Elasticache Redis, and SSM Parameter Store. It includes best practices for multi-architecture support, scripts for deployment, and Terraform for infrastructure automation.

---

## **Key Components**

### 1. **ECR (Elastic Container Registry)**

- **Purpose**: Host your Docker images for ECS.
- **Steps**:
  - Use Terraform to define an ECR repository:
    ```hcl
    resource "aws_ecr_repository" "my_app" {
      name = "my-app"
    }
    ```
  - Build and push Docker images using `buildx` for multi-architecture:
    ```bash
    docker buildx create --use
    docker buildx build --platform linux/amd64,linux/arm64 -t <account_id>.dkr.ecr.<region>.amazonaws.com/my-app:latest . --push
    ```

### 2. **Task Execution Role**

- **Purpose**: Provide ECS tasks with permissions to pull images and send logs.
- **Terraform Example**:

  ```hcl
  resource "aws_iam_role" "task_execution_role" {
    name               = "ecsTaskExecutionRole"
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "ecs-tasks.amazonaws.com" }
        },
      ]
    })

    inline_policy {
      name = "ecs-task-logging"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Effect   = "Allow"
            Resource = "*"
          },
        ]
      })
    }
  }
  ```

### 3. **Task Definition**

- **Purpose**: Define container runtime settings for ECS.
- **Terraform Example**:
  ```hcl
  resource "aws_ecs_task_definition" "my_app" {
  execution_role_arn   = aws_iam_role.task_execution_role.arn
    family                = "my-app"
    container_definitions = jsonencode([
      {
        name      = "my-container"
        image     = "${aws_ecr_repository.my_app.repository_url}:latest"
        memory    = 512
        cpu       = 256
        essential = true
        portMappings = [
          {
            containerPort = 8000
            hostPort      = 8000
          }
        ]
        environment = [
          { name = "AWS_DEFAULT_REGION", value = "ap-southeast-2" }
        ]
        secrets = [
          { name = "DB_PASSWORD", valueFrom = "arn:aws:ssm:..." }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/my-app"
            awslogs-region        = "ap-southeast-2"
          }
        }
      }
    ])
  }
  ```

### 4. **ECS Service Configuration Examples**

#### **Basic Example**

```hcl
resource "aws_ecs_service" "example" {
  name            = "example"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = aws_subnet.private_subnets[*].id
    security_groups = [aws_security_group.service_sg.id]
  }
}
```

#### **Service with ALB Integration**

```hcl
resource "aws_ecs_service" "example_alb" {
  name            = "example-with-alb"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  launch_type     = "FARGATE"
  desired_count   = 3
  network_configuration {
    subnets         = aws_subnet.private_subnets[*].id
    security_groups = [aws_security_group.service_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "example-container"
    container_port   = 8080
  }
}
```

#### **Daemon Scheduling Strategy**

```hcl
resource "aws_ecs_service" "daemon_example" {
  name                = "example-daemon"
  cluster             = aws_ecs_cluster.example.id
  task_definition     = aws_ecs_task_definition.example.arn
  scheduling_strategy = "DAEMON"
}
```

#### **External Deployment Controller**

```hcl
resource "aws_ecs_service" "external_controller" {
  name    = "external-controller-example"
  cluster = aws_ecs_cluster.example.id

  deployment_controller {
    type = "EXTERNAL"
  }
}
```

#### **CloudWatch Deployment Alarms**

```hcl
resource "aws_ecs_service" "deployment_with_alarms" {
  name    = "example-deployment-with-alarms"
  cluster = aws_ecs_cluster.example.id

  alarms {
    enable   = true
    rollback = true
    alarm_names = [
      aws_cloudwatch_metric_alarm.example.alarm_name
    ]
  }
}
```

#### **Fargate Ephemeral Storage Encryption**

```hcl
resource "aws_kms_key" "ephemeral_storage_key" {
  description             = "Fargate ephemeral storage encryption"
  deletion_window_in_days = 7
}

resource "aws_ecs_cluster" "example" {
  name = "example"

  configuration {
    managed_storage_configuration {
      fargate_ephemeral_storage_kms_key_id = aws_kms_key.ephemeral_storage_key.id
    }
  }
}
```

### 5. **SSM Parameter Store for Secrets**

- **Purpose**: Securely store and access sensitive environment variables.
- **Setup Example**:
  ```bash
  aws ssm put-parameter --name "/my-app/db-password" --value "my-secret-password" --type "SecureString"
  ```
- Reference in task definitions with `valueFrom`.

### 6. **RDS Postgres and Elasticache Redis**

- **RDS Example**:
  ```hcl
  resource "aws_db_instance" "postgres" {
    engine            = "postgres"
    instance_class    = "db.t3.micro"
    allocated_storage = 20
    name              = "mydb"
    username          = "admin"
    password          = "supersecret"
    vpc_security_group_ids = [aws_security_group.rds_sg.id]
  }
  ```
- **Elasticache Example**:
  ```hcl
  resource "aws_elasticache_cluster" "redis" {
    cluster_id           = "my-redis"
    engine               = "redis"
    node_type            = "cache.t3.micro"
    num_cache_nodes      = 1
    parameter_group_name = "default.redis7.x"
  }
  ```

---

## **Automation Scripts**

### **1. Build and Push Script**

```bash
#!/bin/bash
set -euo pipefail

# Variables
REGION="ap-southeast-2"
REPO_NAME="my-app"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

# Authenticate and Build
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO_URI
docker buildx build --platform linux/amd64,linux/arm64 -t $REPO_URI:latest . --push
```

### **2. Force Deploy Script**

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
SERVICE="my-service"

aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
```

### **3. Monitor Script**

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
SERVICE="my-service"

aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query "services[0].events" --output table
```

### **4. Connect Script**

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
TASK=$(aws ecs list-tasks --cluster $CLUSTER --query "taskArns[0]" --output text)

aws ecs execute-command --cluster $CLUSTER --task $TASK --container my-container --interactive --command "/bin/bash"
```

---

## **Best Practices**

1. **Infrastructure as Code**:
   - Use Terraform to define all AWS resources.
   - Store Terraform state in an S3 bucket with DynamoDB for state locking.
2. **Multi-Architecture Support**:
   - Use Docker `buildx` to support ARM and x86 architectures.
3. **Centralised Secrets Management**:
   - Use SSM Parameter Store or AWS Secrets Manager for sensitive values.
4. **Monitoring and Logging**:
   - Use CloudWatch for ECS service logs and alarms.
   - Implement dashboards for observability.
5. **Security**:
   - Use least-privilege IAM roles for tasks.
   - Limit security group access to necessary IP ranges or VPCs.

---
