output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.app.arn
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.app.id
}

output "iam_role_arn" {
  description = "IAM role ARN attached to app instances"
  value       = aws_iam_role.app.arn
}

output "instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.app.name
}
