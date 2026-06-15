variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  description = "AWS region (needed in user-data template)"
  type        = string
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID for the region"
  type        = string
  validation {
    condition     = can(regex("^ami-[a-f0-9]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI ID (ami-xxxxxxxx)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.", var.instance_type))
    error_message = "instance_type must be a valid EC2 instance type."
  }
}

variable "private_app_subnet_ids" {
  description = "Private app subnet IDs for the ASG"
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group ID for app instances"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to attach the ASG to"
  type        = string
}

variable "app_artifacts_bucket_arn" {
  description = "ARN of the S3 bucket storing app artifacts (used in IAM policy)"
  type        = string
}

variable "app_artifacts_bucket_name" {
  description = "Name of the S3 bucket storing app artifacts (used in user-data)"
  type        = string
}

variable "app_s3_key" {
  description = "S3 key of the app tarball (e.g. app/app-latest.tar.gz)"
  type        = string
  default     = "app/app-latest.tar.gz"
}

variable "db_kms_key_arn" {
  description = "KMS key ARN used to encrypt the DB secret — required for kms:Decrypt"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret with DB credentials"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
  validation {
    condition     = var.asg_min_size >= 1
    error_message = "asg_min_size must be at least 1."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
  validation {
    condition     = var.asg_max_size >= var.asg_min_size
    error_message = "asg_max_size must be >= asg_min_size."
  }
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "jenkins_url" {
  description = "Base Jenkins URL to trigger builds (empty = skip)"
  type        = string
  default     = ""
}

variable "jenkins_job_name" {
  description = "Jenkins job/pipeline name to trigger"
  type        = string
  default     = "three-tier-deploy"
}

variable "jenkins_user" {
  description = "Jenkins username for API authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_token" {
  description = "Jenkins API token for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
