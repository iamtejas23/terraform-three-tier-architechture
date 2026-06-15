output "app_url" {
  description = "Application URL via the load balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.asg_name
}

output "app_artifacts_bucket" {
  value = aws_s3_bucket.app_artifacts.bucket
}

output "db_secret_arn" {
  value     = module.rds.db_secret_arn
  sensitive = true
}

output "db_secret_name" {
  value = module.rds.db_secret_name
}
