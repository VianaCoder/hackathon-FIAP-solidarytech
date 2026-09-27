variable "aws_region" {
  description = "AWS region used by all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "solidarytech"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zones" {
  description = "Optional explicit AZ list"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway to allow outbound internet access from private subnets"
  type        = bool
  default     = false
}

variable "create_iam_roles" {
  description = "Create IAM roles for EKS cluster and node groups in this account"
  type        = bool
  default     = true
}

variable "cluster_role_arn" {
  description = "EKS control plane role ARN (used when create_iam_roles is false)"
  type        = string
  default     = ""

  validation {
    condition     = var.create_iam_roles || length(trimspace(var.cluster_role_arn)) > 0
    error_message = "cluster_role_arn must be set when create_iam_roles is false."
  }
}

variable "node_role_arn" {
  description = "EKS node role ARN (used when create_iam_roles is false)"
  type        = string
  default     = ""

  validation {
    condition     = var.create_iam_roles || length(trimspace(var.node_role_arn)) > 0
    error_message = "node_role_arn must be set when create_iam_roles is false."
  }
}

variable "use_public_node_group_subnets" {
  description = "Run EKS managed nodes in public subnets to avoid NAT costs"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_group_instance_types" {
  description = "Instance types used in default node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_engine_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16.3"
}

variable "sqs_queue_name" {
  description = "SQS queue name"
  type        = string
  default     = "solidary-donations"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "SolidaryTechVolunteers"
}

variable "dynamodb_hash_key" {
  description = "DynamoDB partition key attribute name"
  type        = string
  default     = "volunteer_id"
}

variable "ecr_repositories" {
  description = "ECR repositories for services"
  type        = list(string)
  default = [
    "ngo-service",
    "donation-service",
    "volunteer-service"
  ]
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}
