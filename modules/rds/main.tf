terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── KMS Key for RDS encryption ────────────────────────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "${local.name_prefix} RDS encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${local.name_prefix}-rds-kms" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ── Secrets Manager — DB credentials ─────────────────────────────────────────
resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#$%&*-_=+[]{}<>"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name_prefix}/rds/credentials"
  description             = "RDS credentials for ${local.name_prefix}"
  kms_key_id              = aws_kms_key.rds.id
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = merge(var.tags, { Name = "${local.name_prefix}-db-secret" })
}

# Secret version is written after the DB instance exists so the host field is accurate
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.this.address
    port     = 3306
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })

  depends_on = [aws_db_instance.this]
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-db-subnet-group"
  subnet_ids  = var.private_db_subnet_ids
  description = "Private DB subnets for ${local.name_prefix}"
  tags        = merge(var.tags, { Name = "${local.name_prefix}-db-subnet-group" })
}

# ── Parameter Group ───────────────────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-mysql8"
  family      = "mysql8.0"
  description = "${local.name_prefix} MySQL 8 parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-mysql8-pg" })
}

# ── Enhanced Monitoring Role ──────────────────────────────────────────────────
data "aws_iam_policy_document" "rds_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_assume.json
  tags               = merge(var.tags, { Name = "${local.name_prefix}-rds-monitoring" })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── RDS Instance ──────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier     = "${local.name_prefix}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.multi_az
  publicly_accessible = false

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.name_prefix}-final-snapshot" : null
  copy_tags_to_snapshot     = true

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? aws_kms_key.rds.arn : null

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = merge(var.tags, { Name = "${local.name_prefix}-db" })
}
