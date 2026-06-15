#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Values injected by Terraform templatefile() — use plain $VAR (no braces) for bash below
APP_BUCKET="${app_bucket}"
APP_KEY="${app_key}"
DB_SECRET_ARN="${db_secret_arn}"
REGION="${aws_region}"
ENVIRONMENT="${environment}"

echo "=== Bootstrap start: environment=$ENVIRONMENT ==="

# System updates and dependencies
dnf update -y
dnf install -y python3 python3-pip tar gzip shadow-utils

# Ensure AWS CLI v2 is available (comes pre-installed on AL2023)
aws --version

# Dedicated non-root user for the app process
useradd -r -s /sbin/nologin appuser

# Download app artifact from S3 using the instance IAM role
mkdir -p /opt/app
aws s3 cp "s3://$APP_BUCKET/$APP_KEY" /tmp/app.tar.gz --region "$REGION"
tar -xzf /tmp/app.tar.gz -C /opt/app
rm /tmp/app.tar.gz
chown -R appuser:appuser /opt/app

# Install Python dependencies
pip3 install -r /opt/app/requirements.txt --no-cache-dir

# systemd service unit
cat > /etc/systemd/system/app.service <<UNIT
[Unit]
Description=Three-Tier Flask Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/app
Environment="DB_SECRET_ARN=$DB_SECRET_ARN"
Environment="AWS_REGION=$REGION"
Environment="ENVIRONMENT=$ENVIRONMENT"
Environment="APP_PORT=8080"
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 --timeout 60 --access-logfile - app:app
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable app
systemctl start app

# Wait for the app to be healthy, then seed the DB schema
echo "=== Waiting for app readiness ==="
for i in $(seq 1 12); do
  if curl -sf http://localhost:8080/health >/dev/null 2>&1; then
    echo "App healthy after $((i * 5))s"
    curl -sf http://localhost:8080/db/init && echo "DB initialized" || echo "DB init skipped (may already exist)"
    break
  fi
  sleep 5
done

echo "=== Bootstrap complete ==="
