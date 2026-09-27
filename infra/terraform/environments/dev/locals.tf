data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  eks_cluster_role_arn = var.create_iam_roles ? aws_iam_role.eks_cluster[0].arn : var.cluster_role_arn
  eks_node_role_arn    = var.create_iam_roles ? aws_iam_role.eks_nodes[0].arn : var.node_role_arn

  eks_node_subnet_ids = var.use_public_node_group_subnets ? module.networking.public_subnet_ids : module.networking.private_subnet_ids

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Phase       = "5"
    },
    var.tags
  )

  rds_instances = {
    ngo = {
      identifier          = "${local.name_prefix}-ngo-db"
      db_name             = "ngo_db"
      username            = "ngo_admin"
      instance_class      = var.rds_instance_class
      allocated_storage   = 20
      engine_version      = var.rds_engine_version
      multi_az            = false
      publicly_accessible = false
    }
    donation = {
      identifier          = "${local.name_prefix}-donation-db"
      db_name             = "donation_db"
      username            = "donation_admin"
      instance_class      = var.rds_instance_class
      allocated_storage   = 20
      engine_version      = var.rds_engine_version
      multi_az            = false
      publicly_accessible = false
    }
  }

  node_groups = {
    default = {
      desired_size   = 3
      max_size       = 3
      min_size       = 1
      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
    }
  }
}
