output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "RDS endpoint hostname (no port)"
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "db_secret_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.db.name
}

output "kms_key_arn" {
  description = "KMS key ARN used for RDS encryption"
  value       = aws_kms_key.rds.arn
}
