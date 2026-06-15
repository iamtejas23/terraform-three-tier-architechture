variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Exactly 2 AZs to deploy into"
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones are required."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs are required."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets (one per AZ)"
  type        = list(string)
  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2
    error_message = "Exactly 2 private app subnet CIDRs are required."
  }
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private DB subnets (one per AZ)"
  type        = list(string)
  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Exactly 2 private DB subnet CIDRs are required."
  }
}

variable "tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
  default     = {}
}
