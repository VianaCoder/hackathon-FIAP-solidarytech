locals {
  common_tags = merge(var.tags, {
    Module = "dynamodb"
  })
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = var.table_name
  })
}
