output "app_url" {
  description = "Application URL via the load balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "alb_dns_name" {
  description = "Raw ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "asg_name" {
  description = "Auto Scaling Group name (use for SSM sessions and SSM Run Command)"
  value       = module.compute.asg_name
}

output "app_artifacts_bucket" {
  description = "S3 bucket where app tarballs are stored"
  value       = aws_s3_bucket.app_artifacts.bucket
}

output "db_secret_arn" {
  description = "Secrets Manager secret ARN — fetch with: aws secretsmanager get-secret-value --secret-id <arn>"
  value       = module.rds.db_secret_arn
  sensitive   = true
}

output "db_secret_name" {
  description = "Secrets Manager secret name"
  value       = module.rds.db_secret_name
}
