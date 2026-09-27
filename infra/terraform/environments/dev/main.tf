module "networking" {
  source = "../../modules/networking"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  az_count           = 2
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name          = "${local.name_prefix}-eks"
  cluster_role_arn      = local.eks_cluster_role_arn
  node_role_arn         = local.eks_node_role_arn
  kubernetes_version    = var.kubernetes_version
  cluster_subnet_ids    = module.networking.private_subnet_ids
  node_group_subnet_ids = local.eks_node_subnet_ids
  node_groups           = local.node_groups
  admin_principal_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-deployer",
  ]
  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                 = local.name_prefix
  vpc_id                      = module.networking.vpc_id
  subnet_ids                  = module.networking.private_subnet_ids
  allowed_cidr_blocks         = [module.networking.vpc_cidr]
  db_instances                = local.rds_instances
  use_managed_master_password = true
  skip_final_snapshot         = true
  backup_retention_period     = 1
  tags                        = local.common_tags
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name = var.dynamodb_table_name
  hash_key   = var.dynamodb_hash_key
  tags       = local.common_tags
}

module "sqs" {
  source = "../../modules/sqs"

  queue_name = var.sqs_queue_name
  tags       = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = var.ecr_repositories
  scan_on_push = true
  tags         = local.common_tags
}
