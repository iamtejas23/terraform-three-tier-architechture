variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state (e.g. threetier-tf-state-123456789012)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "S3 bucket name must be 3–63 chars, lowercase, alphanumeric and hyphens."
  }
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-state-lock"
}
