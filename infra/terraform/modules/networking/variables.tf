variable "name_prefix" {
  description = "Prefix used in resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to use. If empty, the first az_count available AZs are used"
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of AZs used when availability_zones is empty"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Creates a single NAT Gateway for private subnet egress"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
