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

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${local.name_prefix}-vpc" })
}

# ── Public subnets (ALB) ─────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# ── Private-app subnets (ASG) ─────────────────────────────────────────────────
resource "aws_subnet" "private_app" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_app_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-private-app-${var.availability_zones[count.index]}"
    Tier = "private-app"
  })
}

# ── Private-db subnets (RDS) — no route to internet ──────────────────────────
resource "aws_subnet" "private_db" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-private-db-${var.availability_zones[count.index]}"
    Tier = "private-db"
  })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${local.name_prefix}-igw" })
}

# ── NAT Gateways — one per AZ for high availability ──────────────────────────
resource "aws_eip" "nat" {
  count      = length(var.availability_zones)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags       = merge(var.tags, { Name = "${local.name_prefix}-nat-eip-${count.index + 1}" })
}

resource "aws_nat_gateway" "this" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.this]
  tags          = merge(var.tags, { Name = "${local.name_prefix}-nat-${var.availability_zones[count.index]}" })
}

# ── Route tables ──────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# App subnets: one route table per AZ (each points to its own NAT GW)
resource "aws_route_table" "private_app" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-private-app-rt-${var.availability_zones[count.index]}" })
}

resource "aws_route_table_association" "private_app" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# DB subnets: explicit route table with NO default route — fully isolated
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${local.name_prefix}-private-db-rt" })
}

resource "aws_route_table_association" "private_db" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}
