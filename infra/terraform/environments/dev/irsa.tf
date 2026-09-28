# IRSA (IAM Roles for Service Accounts) wiring for pods that call AWS APIs
# directly: volunteer-service (DynamoDB) and donation-service (SQS).
#
# Registers the EKS cluster's OIDC issuer as an IAM identity provider, then
# creates one IAM role per service scoped to its Kubernetes ServiceAccount
# subject (namespace + service account name), following the standard IRSA
# trust policy pattern.

data "tls_certificate" "eks_oidc" {
  url = module.eks.oidc_issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = local.common_tags
}

locals {
  oidc_provider_host = replace(module.eks.oidc_issuer, "https://", "")
}

# ---------------------------------------------------------------------------
# volunteer-service: read/write access to the SolidaryTechVolunteers table
# ---------------------------------------------------------------------------

resource "aws_iam_role" "volunteer_service_irsa" {
  name = "${local.name_prefix}-volunteer-service-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_host}:sub" = "system:serviceaccount:ns-volunteer:volunteer-service"
            "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "volunteer_service_dynamodb" {
  name = "${local.name_prefix}-volunteer-service-dynamodb"
  role = aws_iam_role.volunteer_service_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = [
          module.dynamodb.table_arn,
          "${module.dynamodb.table_arn}/index/*",
        ]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# donation-service: send access to the donations SQS queue
# ---------------------------------------------------------------------------

resource "aws_iam_role" "donation_service_irsa" {
  name = "${local.name_prefix}-donation-service-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_host}:sub" = "system:serviceaccount:ns-donation:donation-service"
            "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "donation_service_sqs" {
  name = "${local.name_prefix}-donation-service-sqs"
  role = aws_iam_role.donation_service_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
        ]
        Resource = module.sqs.queue_arn
      }
    ]
  })
}
