# Migrating from Docker Compose to AWS ECS with Fargate Using Terraform

This guide explains how to migrate a `docker-compose.yml` setup to AWS ECS with Fargate, incorporating key AWS features like Application Load Balancers (ALB), ECR repositories, IAM roles, RDS Postgres, Elasticache Redis, and SSM Parameter Store. It includes practical examples for multi-service and single-task setups, multi-architecture support, scripts for deployment, and Terraform automation. The document goes into detailed configurations and best practices to ensure a smooth transition.

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
        name      = "rails-app"
        image     = "${aws_ecr_repository.my_app.repository_url}:latest"
        memory    = 512
        cpu       = 256
        essential = true
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
        image     = "nginx:latest"
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
    container_name   = "nginx"
    container_port   = 80
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

---

## **Connect Scripts**

### **Single-Task Connect Script**

#### **Use Case**

- Debugging or managing a single container.

#### **Example**

- **Rails App Only**:

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
TASK=$(aws ecs list-tasks --cluster $CLUSTER --query "taskArns[0]" --output text)
aws ecs execute-command --cluster $CLUSTER --task $TASK --container rails-app --interactive --command "/bin/bash"
```

### **Multi-Task Connect Script**

#### **Use Case**

- Debugging multi-service setups like Rails, Sidekiq, and Nginx.

#### **Example**

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
TASKS=$(aws ecs list-tasks --cluster $CLUSTER --query "taskArns" --output json | jq -r '.[]')

if [ -z "$TASKS" ]; then
  echo "No running tasks found in cluster $CLUSTER"
  exit 1
fi

for TASK in $TASKS; do
  CONTAINERS=$(aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK --query "tasks[0].containers[*].name" --output json | jq -r '.[]')
  for CONTAINER in $CONTAINERS; do
    echo "Connecting to task: $TASK, container: $CONTAINER"
    aws ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER --interactive --command "/bin/bash"
  done
done
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

### **4. Advanced Connection Script**

#### **Description**:

Adds filtering options to connect only to specific services or containers.

```bash
#!/bin/bash
set -euo pipefail

CLUSTER="my-cluster"
SERVICE_NAME="my-service"

TASKS=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE_NAME --query "taskArns" --output json | jq -r '.[]')
if [ -z "$TASKS" ]; then
  echo "No running tasks for service: $SERVICE_NAME"
  exit 1
fi

for TASK in $TASKS; do
  CONTAINERS=$(aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK --query "tasks[0].containers[*].name" --output json | jq -r '.[]')
  for CONTAINER in $CONTAINERS; do
    echo "Connecting to task: $TASK,

```
