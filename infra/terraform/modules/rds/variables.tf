variable "name_prefix" {
  description = "Prefix used in resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where DB security group is created"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for DB subnet group"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect on PostgreSQL port"
  type        = list(string)
  default     = []
}

variable "db_instances" {
  description = "Map of PostgreSQL instances to create"
  type = map(object({
    identifier          = string
    db_name             = string
    username            = string
    password            = optional(string)
    instance_class      = string
    allocated_storage   = number
    engine_version      = string
    multi_az            = optional(bool, false)
    publicly_accessible = optional(bool, false)
  }))
}

variable "use_managed_master_password" {
  description = "Use AWS-managed password in Secrets Manager instead of plain text"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (recommended false for production)"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
