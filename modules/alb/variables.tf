variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Prevents ALB from being accidentally deleted"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs (empty string = disabled)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
