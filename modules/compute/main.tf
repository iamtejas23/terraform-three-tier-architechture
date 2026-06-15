terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── IAM Role ──────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = merge(var.tags, { Name = "${local.name_prefix}-app-role" })
}

# SSM access — no SSH key required
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege S3 access scoped to the artifacts bucket only
data "aws_iam_policy_document" "s3_app" {
  statement {
    sid     = "ReadAppArtifacts"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      var.app_artifacts_bucket_arn,
      "${var.app_artifacts_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_app" {
  name   = "${local.name_prefix}-s3-app-policy"
  policy = data.aws_iam_policy_document.s3_app.json
}

resource "aws_iam_role_policy_attachment" "s3_app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.s3_app.arn
}

# Least-privilege Secrets Manager + KMS access for the DB secret
# KMS Decrypt is required because the secret is encrypted with a CMK
data "aws_iam_policy_document" "secrets" {
  statement {
    sid       = "ReadDBSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }

  statement {
    sid     = "DecryptDBSecretKMS"
    actions = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.db_kms_key_arn]
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "${local.name_prefix}-secrets-policy"
  policy = data.aws_iam_policy_document.secrets.json
}

resource "aws_iam_role_policy_attachment" "secrets" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.secrets.arn
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name_prefix}-app-profile"
  role = aws_iam_role.app.name
}

# ── Launch Template ───────────────────────────────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
    delete_on_termination       = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_bucket    = var.app_artifacts_bucket_name
    app_key       = var.app_s3_key
    db_secret_arn = var.db_secret_arn
    aws_region    = var.aws_region
    environment   = var.environment
  }))

  # IMDSv2 required — prevents SSRF-based metadata exfiltration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${local.name_prefix}-app-server" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${local.name_prefix}-app-volume" })
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-app-lt" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                      = "${local.name_prefix}-app-asg"
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = var.private_app_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${local.name_prefix}-app-server" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# ── Auto Scaling Policies ─────────────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 75
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  tags                = var.tags
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name_prefix}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  tags                = var.tags
}

# ── Jenkins Trigger ───────────────────────────────────────────────────────────
# Fires only when jenkins_url is set. Calls the pipeline with parameters so
# Jenkins can run SSM-based rolling deploys without re-running Terraform.
resource "null_resource" "jenkins_trigger" {
  count = var.jenkins_url != "" ? 1 : 0

  triggers = {
    asg_name   = aws_autoscaling_group.app.name
    app_s3_key = var.app_s3_key
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -o /dev/null -w "%%{http_code}" \
        -X POST "${var.jenkins_url}/job/${var.jenkins_job_name}/buildWithParameters" \
        --user "${var.jenkins_user}:${var.jenkins_token}" \
        --data "ENVIRONMENT=${var.environment}&ACTION=deploy&ASG_NAME=${aws_autoscaling_group.app.name}" \
        --fail-with-body \
      && echo " Jenkins build triggered" \
      || echo " Jenkins trigger failed — check JENKINS_URL and token"
    EOT
  }

  depends_on = [aws_autoscaling_group.app]
}
