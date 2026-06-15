# Run this ONCE before using any environment backend.
# It creates the S3 bucket and DynamoDB table for Terraform remote state.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply -var="state_bucket_name=<globally-unique-name>"
#
# Then update backend.tf in each environment with your bucket name.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  tags = {
    Name      = var.state_bucket_name
    ManagedBy = "Terraform"
    Purpose   = "terraform-remote-state"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery { enabled = true }

  tags = {
    Name      = var.lock_table_name
    ManagedBy = "Terraform"
    Purpose   = "terraform-state-lock"
  }
}

output "state_bucket_name" {
  description = "Copy this into backend.tf for each environment"
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.lock.name
}
