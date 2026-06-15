terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "app_artifacts" {
  bucket        = "${var.project}-${var.environment}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app_artifacts" {
  bucket                  = aws_s3_bucket.app_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "null_resource" "upload_app" {
  triggers = {
    app_hash = sha256(join("", [
      for f in sort(fileset("${path.root}/../../app", "**")) :
      filesha256("${path.root}/../../app/${f}")
    ]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      tar -czf /tmp/${var.project}-${var.environment}-app.tar.gz \
        -C ${path.root}/../../app . && \
      aws s3 cp /tmp/${var.project}-${var.environment}-app.tar.gz \
        s3://${aws_s3_bucket.app_artifacts.bucket}/app/app-latest.tar.gz \
        --region ${var.aws_region} && \
      echo "App uploaded to s3://${aws_s3_bucket.app_artifacts.bucket}/app/app-latest.tar.gz"
    EOT
  }

  depends_on = [
    aws_s3_bucket_public_access_block.app_artifacts,
    aws_s3_bucket_versioning.app_artifacts,
  ]
}

module "vpc" {
  source = "../../modules/vpc"

  project                  = var.project
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  tags                     = local.common_tags
}

module "security" {
  source = "../../modules/security"

  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  tags        = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  project                    = var.project
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  alb_sg_id                  = module.security.alb_sg_id
  enable_deletion_protection = var.alb_deletion_protection
  tags                       = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  project                     = var.project
  environment                 = var.environment
  private_db_subnet_ids       = module.vpc.private_db_subnet_ids
  rds_sg_id                   = module.security.rds_sg_id
  db_name                     = var.db_name
  db_username                 = var.db_username
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  max_allocated_storage       = var.db_max_allocated_storage
  multi_az                    = var.db_multi_az
  deletion_protection         = var.db_deletion_protection
  backup_retention_days       = var.db_backup_retention_days
  secret_recovery_window_days  = var.secret_recovery_window_days
  performance_insights_enabled = var.performance_insights_enabled
  tags                         = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project                   = var.project
  environment               = var.environment
  aws_region                = var.aws_region
  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  private_app_subnet_ids    = module.vpc.private_app_subnet_ids
  app_sg_id                 = module.security.app_sg_id
  target_group_arn          = module.alb.target_group_arn
  app_artifacts_bucket_arn  = aws_s3_bucket.app_artifacts.arn
  app_artifacts_bucket_name = aws_s3_bucket.app_artifacts.bucket
  app_s3_key                = "app/app-latest.tar.gz"
  db_kms_key_arn            = module.rds.kms_key_arn
  db_secret_arn             = module.rds.db_secret_arn
  asg_min_size              = var.asg_min_size
  asg_max_size              = var.asg_max_size
  asg_desired_capacity      = var.asg_desired_capacity
  jenkins_url               = var.jenkins_url
  jenkins_job_name          = var.jenkins_job_name
  jenkins_user              = var.jenkins_user
  jenkins_token             = var.jenkins_token
  tags                      = local.common_tags

  depends_on = [null_resource.upload_app]
}
