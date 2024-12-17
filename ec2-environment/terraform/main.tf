# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "UbuntuBox2025"
      Environment = "Development"
      Terraform   = "true"
    }
  }
}

# Network Data Sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id != null ? var.subnet_id : sort(data.aws_subnets.default.ids)[0]
}

# AMI Mapping
locals {
  ubuntu_amis = {
    "us-west-1" = {
      "amd64" = "ami-0a9cd4a0a5f6c06bb"
      "arm64" = "ami-0de5737cddf1c59b8"
    }
    "ap-southeast-2" = {
      "amd64" = "ami-0eb5e2a4908880da3"
      "arm64" = "ami-0e4f8a9457c962abb"
    }
    "ap-southeast-4" = {
      "amd64" = "ami-0fcd26ca3ba0585b6"
      "arm64" = "ami-0299283ac4b0e73a9"
    }
    "us-east-1" = {
      "amd64" = "ami-00f3c44a2de45a590"
      "arm64" = "ami-070669ed9d7e8c691"
    }
    "eu-west-1" = {
      "amd64" = "ami-0d8bd47e6d44801e1"
      "arm64" = "ami-01cbbf6d4d6a0ee3b"
    }
  }

  instance_type = var.arch == "arm64" ? "t4g.medium" : "t3.medium"
  ami_id        = local.ubuntu_amis[var.region][var.arch]
}

# SSH Key
resource "aws_key_pair" "ubuntu_box" {
  key_name   = "ubuntu-box-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFghqMnnpyftkhyAnsg82i+F9nw8Xh9U/8u/J2DggLcwlOUKnlG8T55gSMchE81n+pUdjn6fG6S85aQhCdAQANzjC+eQYiFU184ZqWBIS1DfnJwfqGLeExjl2HYvgcjsailO5EIWT0RKCTLpLGtW2dNA6qtj4SJy5nJP1C3l5R1H5UNT90MXh41E0/7wCNv2eNWZeWaWx9bcSh6lxx0u4S0grMTuh7uPOnSFysoQsFC+2Sa+YzOLrNA2S1Nwkc735QM2puzMs+488Qsiicl7OrlZciALQ1o82uodxlBD1FQJvnQGXfbTjNEOpxi5xFzESiDFfC62sYkzV8GjWia2TJDZow4pK/OnBkPkwYu6DZ02hLgSS6MYHliMBF7z5uUNsv6PpKVgkyIz2ZxjR02U8Mx0IbISf8iK8k8uf3IptPwLk+Dc/nyX/yYTa8VrACx/owI+qflFA6DgpTaI4CCXOJSgFZSIg/6W1inWNxb5iciQpfS73xS9aJy4HDGoH3YuEhyYkkxP4Pd47xt/hUXcY+Z1cK7/7S7iAVKYLM5Wd/PoMHxoT71sfICqnUeszY5CLp4UY9ZrAvG5sORGXQJ8OTLJO1m+6mL7uWv43+daUcpioucr9qcMRJshwSEJdpBUn4VW5plaQzAzUUlE3YBI7szSJIFkCb6Fe/y+9P6UGHQ== dean@deanlofts.xyz"
}

# Security Group
resource "aws_security_group" "ubuntu_box" {
  name_prefix = "ubuntu-box-"
  description = "Security group for Ubuntu Box 2025"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
    description = "SSH access"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ssm_endpoints.id]
    description     = "HTTPS for SSM"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SSM Endpoints Security Group
resource "aws_security_group" "ssm_endpoints" {
  name_prefix = "ssm-endpoints-"
  description = "Security group for SSM endpoints"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = data.aws_vpc.default.id
  service_name       = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [data.aws_subnet.selected.id]
  security_group_ids = [aws_security_group.ssm_endpoints.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id             = data.aws_vpc.default.id
  service_name       = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [data.aws_subnet.selected.id]
  security_group_ids = [aws_security_group.ssm_endpoints.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id             = data.aws_vpc.default.id
  service_name       = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [data.aws_subnet.selected.id]
  security_group_ids = [aws_security_group.ssm_endpoints.id]

  private_dns_enabled = true
}

# EC2 Instance Profile and Role
resource "aws_iam_instance_profile" "ubuntu_box" {
  name = "ubuntu-box-profile"
  role = aws_iam_role.ubuntu_box.name
}

# IAM Role
resource "aws_iam_role" "ubuntu_box" {
  name = "ubuntu-box-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ubuntu_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ubuntu_box.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_read_only_access" {
  role       = aws_iam_role.ubuntu_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_read_only_access" {
  role       = aws_iam_role.ubuntu_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "efs_read_only_access" {
  role       = aws_iam_role.ubuntu_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemReadOnlyAccess"
}

# EC2 Instance
resource "aws_instance" "ubuntu_box" {
  ami                    = local.ami_id
  instance_type          = local.instance_type
  subnet_id              = data.aws_subnet.selected.id
  key_name              = aws_key_pair.ubuntu_box.key_name
  iam_instance_profile  = aws_iam_instance_profile.ubuntu_box.name
  vpc_security_group_ids = [aws_security_group.ubuntu_box.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("../scripts/cloud-init.yml", {
    region = var.region
    arch   = var.arch
  }))

  monitoring = true

  tags = {
    Name = "ubuntu-box-2025"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ubuntu_box" {
  name              = "/ubuntu-box/system"
  retention_in_days = 30

  tags = {
    Name = "ubuntu-box-logs"
  }
}