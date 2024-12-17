# variables.tf

variable "region" {
  description = "AWS region to deploy the Ubuntu Box"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^(us-west-1|ap-southeast-2|ap-southeast-4|us-east-1|eu-west-1)$", var.region))
    error_message = "Region must be one of: us-west-1, ap-southeast-2, ap-southeast-4, us-east-1, eu-west-1"
  }
}

variable "arch" {
  description = "Architecture for the Ubuntu Box (amd64 or arm64)"
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "Architecture must be either amd64 or arm64"
  }
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in. If not specified, the first default subnet will be used."
  type        = string
  default     = null
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Note: Should be restricted in production
}