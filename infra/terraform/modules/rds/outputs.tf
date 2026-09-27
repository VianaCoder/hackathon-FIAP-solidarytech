output "security_group_id" {
  description = "Security group ID used by RDS instances"
  value       = aws_security_group.this.id
}

output "db_endpoints" {
  description = "Map of DB instance endpoints"
  value       = { for key, db in aws_db_instance.this : key => db.address }
}

output "db_arns" {
  description = "Map of DB instance ARNs"
  value       = { for key, db in aws_db_instance.this : key => db.arn }
}

output "master_user_secret_arns" {
  description = "Map of generated Secrets Manager ARNs when managed passwords are enabled"
  value = {
    for key, db in aws_db_instance.this :
    key => try(db.master_user_secret[0].secret_arn, null)
  }
}
