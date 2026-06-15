terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── ALB Security Group ────────────────────────────────────────────────────────
# Only resource that accepts 0.0.0.0/0; all other SGs chain by reference.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB: HTTP/HTTPS from internet only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Egress rule defined separately so it can reference the app SG without a cycle
resource "aws_security_group_rule" "alb_egress_app" {
  type                     = "egress"
  description              = "ALB to app tier on port 8080"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.alb.id
}

# ── App Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "App tier: accepts traffic from ALB only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name_prefix}-app-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "app_ingress_alb" {
  type                     = "ingress"
  description              = "From ALB on app port"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress_rds" {
  type                     = "egress"
  description              = "App to RDS MySQL"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.app.id
}

# HTTPS out: reach SSM endpoint, S3, Secrets Manager through NAT
resource "aws_security_group_rule" "app_egress_https" {
  type              = "egress"
  description       = "HTTPS out for AWS API calls (SSM, Secrets Manager, S3)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

# HTTP out: yum/apt package repos during bootstrap
resource "aws_security_group_rule" "app_egress_http" {
  type              = "egress"
  description       = "HTTP out for package repos during bootstrap"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

# ── RDS Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS: MySQL from app tier only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name_prefix}-rds-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_app" {
  type                     = "ingress"
  description              = "MySQL from app tier"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_egress_app" {
  type                     = "egress"
  description              = "Ephemeral port responses back to app tier"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.rds.id
}
