output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB Route 53 hosted zone ID"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "App target group ARN"
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "App target group name"
  value       = aws_lb_target_group.app.name
}
