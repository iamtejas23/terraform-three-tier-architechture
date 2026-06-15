variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_db_subnet_ids" {
  description = "Private DB subnet IDs (no internet route)"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "RDS security group ID"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, digits, and underscores."
  }
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username)) && length(var.db_username) <= 16
    error_message = "db_username must start with a letter, be alphanumeric/underscore, and max 16 characters."
  }
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
  validation {
    condition     = startswith(var.instance_class, "db.")
    error_message = "instance_class must start with 'db.'."
  }
}

variable "allocated_storage" {
  description = "Initial storage in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "allocated_storage must be between 20 and 65536 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ for HA (always true in prod)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental deletion"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Days to retain automated backups (1–35)"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "secret_recovery_window_days" {
  description = "Days before a deleted secret is permanently removed"
  type        = number
  default     = 7
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights (not supported on db.t3.micro)"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
