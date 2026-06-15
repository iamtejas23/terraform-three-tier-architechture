variable "project" {
  description = "Project identifier (lowercase, hyphens only)"
  type        = string
  default     = "threetier"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "project must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "iamtejas23"
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ── ALB ───────────────────────────────────────────────────────────────────────
variable "alb_deletion_protection" {
  type    = bool
  default = false
}

# ── Compute ───────────────────────────────────────────────────────────────────
variable "ami_id" {
  description = "Amazon Linux 2023 AMI for us-east-1"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 3
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 50
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 3
}

variable "secret_recovery_window_days" {
  type    = number
  default = 7
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights (not supported on db.t3.micro)"
  type        = bool
  default     = false
}

# ── Jenkins (optional) ────────────────────────────────────────────────────────
variable "jenkins_url" {
  description = "Jenkins base URL. Leave empty to skip auto-trigger."
  type        = string
  default     = ""
}

variable "jenkins_job_name" {
  type    = string
  default = "three-tier-deploy"
}

variable "jenkins_user" {
  type      = string
  sensitive = true
  default   = ""
}

variable "jenkins_token" {
  type      = string
  sensitive = true
  default   = ""
}
