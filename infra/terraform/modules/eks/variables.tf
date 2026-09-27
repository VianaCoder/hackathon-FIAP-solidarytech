variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN used by EKS control plane"
  type        = string
}

variable "node_role_arn" {
  description = "Default IAM role ARN used by EKS node groups"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnet IDs used by the EKS control plane"
  type        = list(string)
}

variable "node_group_subnet_ids" {
  description = "Default subnet IDs for node groups"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.30"
}

variable "endpoint_public_access" {
  description = "Whether EKS API endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Whether EKS API endpoint is privately accessible"
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Map of node groups to create"
  type = map(object({
    desired_size   = number
    max_size       = number
    min_size       = number
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
    subnet_ids     = optional(list(string))
    node_role_arn  = optional(string)
    labels         = optional(map(string), {})
  }))
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "admin_principal_arns" {
  description = "IAM principal ARNs to grant EKS cluster admin access via access entries"
  type        = list(string)
  default     = []
}
