# Terraform Three-Tier AWS Architecture

Production-grade, modular Terraform for a secure 3-tier web application on AWS — VPC → ALB → Auto Scaling EC2 → Multi-AZ RDS MySQL — with automated app deployment on every `terraform apply`.

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────┐
│  Application Load Balancer  (public subnets) │  ← HTTP :80, HTTPS :443 open
│  ALB Security Group                          │    to 0.0.0.0/0 only here
└────────────────────┬────────────────────────┘
                     │ port 8080 (SG reference only)
                     ▼
┌─────────────────────────────────────────────┐
│  Auto Scaling Group  (private-app subnets)   │  ← No public IP, no SSH key
│  EC2 — Amazon Linux 2023 — Flask app         │    Access via SSM Session Manager
│  App Security Group                          │
└────────────────────┬────────────────────────┘
                     │ port 3306 (SG reference only)
                     ▼
┌─────────────────────────────────────────────┐
│  RDS MySQL 8.0  (private-db subnets)         │  ← Multi-AZ, KMS encrypted
│  RDS Security Group                          │    No internet route at all
│  Credentials in Secrets Manager              │
└─────────────────────────────────────────────┘

VPC CIDR  dev:  10.0.0.0/16   AZs: us-east-1a / us-east-1b
          prod: 10.1.0.0/16
```

**Subnet layout (per environment)**

| Tier         | Subnet CIDRs                         | Route to internet |
|--------------|--------------------------------------|-------------------|
| Public (ALB) | 10.x.1.0/24 · 10.x.2.0/24           | Via IGW           |
| Private-app  | 10.x.11.0/24 · 10.x.12.0/24         | Via NAT Gateway   |
| Private-db   | 10.x.21.0/24 · 10.x.22.0/24         | **None**          |

---

## Repository Layout

```
.
├── bootstrap/               # One-time: creates S3 + DynamoDB for remote state
│   ├── main.tf
│   └── variables.tf
│
├── modules/                 # Reusable modules — no hardcoded values
│   ├── vpc/                 # VPC, subnets, IGW, NAT GWs, route tables
│   ├── security/            # Security groups chained by reference
│   ├── alb/                 # Internet-facing ALB, target group, listener
│   ├── compute/             # IAM role, launch template, ASG, CloudWatch alarms
│   └── rds/                 # KMS key, Secrets Manager, RDS MySQL
│
├── environments/
│   ├── dev/                 # Dev: single-AZ RDS, t3.micro, 1 instance
│   └── prod/                # Prod: Multi-AZ RDS, t3.medium, 2+ instances
│
├── app/                     # Flask application (deployed automatically on apply)
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── templates/
│       └── index.html       # Dark-mode UI — add/delete items, live row count
│
├── docker-compose.yml       # Local test: app + MySQL, zero AWS dependencies
└── pipelinescript           # Jenkins declarative pipeline
```

---

## Prerequisites

| Tool           | Minimum version |
|----------------|-----------------|
| Terraform      | 1.5.0           |
| AWS CLI        | 2.x             |
| Docker + Compose | any recent    |
| Python         | 3.11 (local dev only) |

AWS credentials must be available in your environment (`~/.aws/credentials` or environment variables `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).

---

## Quick Start

### Step 1 — Create the remote backend (one time only)

```bash
cd bootstrap

terraform init

# Replace the bucket name with something globally unique
terraform apply \
  -var="state_bucket_name=threetier-tf-state-$(aws sts get-caller-identity \
    --query Account --output text)"
```

Copy the `state_bucket_name` output, then update **both** `environments/dev/backend.tf` and `environments/prod/backend.tf`:

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-actual-bucket-name"   # ← paste here
    key            = "three-tier/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Step 2 — Deploy dev

```bash
cd environments/dev

terraform init

# Verify the AMI ID is current for your region before applying
terraform plan -var-file=terraform.tfvars

terraform apply -var-file=terraform.tfvars
```

**What happens on `apply`:**

1. Infrastructure is provisioned (VPC → ALB → ASG → RDS).
2. `app/` is packaged into a tarball and uploaded to S3 automatically.
3. Each EC2 instance downloads the tarball on boot, installs dependencies, and starts the app as a systemd service.
4. The app calls `/db/init` on startup — creates the `items` table and seeds it with starter rows.
5. If `jenkins_url` is set in `terraform.tfvars`, Jenkins is triggered via API to handle subsequent rolling deployments.

After apply, the output `app_url` gives you the URL to open in a browser.

### Step 3 — Deploy prod

```bash
cd environments/prod

terraform init
terraform apply -var-file=terraform.tfvars
```

---

## Local Testing (no AWS account needed)

```bash
# Start the stack
docker compose up --build

# Open the UI in your browser
open http://localhost:8080           # dark-mode UI — add/delete items visually

# Or hit the API directly
curl http://localhost:8080/health    # {"status":"ok"}
curl http://localhost:8080/db/init   # creates table, seeds 3 starter rows
curl http://localhost:8080/api/items # all rows as JSON
```

The app detects the absence of `DB_SECRET_ARN` and falls back to plain environment variables (`DB_HOST`, `DB_USER`, etc.) defined in `docker-compose.yml`.

---

## Application Endpoints

| Endpoint          | Method | Description                                              |
|-------------------|--------|----------------------------------------------------------|
| `/`               | GET    | **HTML UI** — add items, delete items, live row count    |
| `/health`         | GET    | Health check — returns `{"status":"ok"}`                 |
| `/db/init`        | GET    | Creates table + seeds 3 starter rows (idempotent)        |
| `/items`          | POST   | Add a new item (form submit from UI)                     |
| `/items/<id>/delete` | POST | Delete an item by ID (button in UI)                   |
| `/api/items`      | GET    | Returns all rows as JSON                                 |

---

## Environment Differences

| Setting                      | dev              | prod (free tier) | prod (upgrade target)  |
|------------------------------|------------------|------------------|------------------------|
| VPC CIDR                     | 10.0.0.0/16      | 10.1.0.0/16      | 10.1.0.0/16            |
| EC2 instance type            | t3.micro         | t3.small         | t3.small+              |
| ASG desired capacity         | 1                | 2                | 2+                     |
| RDS instance class           | db.t3.micro      | db.t3.micro      | db.t3.medium+          |
| RDS Multi-AZ                 | false            | false            | **true**               |
| Performance Insights         | false            | false            | **true**               |
| RDS deletion protection      | false            | false            | **true**               |
| Backup retention             | 3 days           | 1 day            | 7 days                 |
| ALB deletion protection      | false            | true             | true                   |
| Secret recovery window       | 7 days           | 7 days           | 30 days                |

> **Free-tier note:** The current prod tfvars are tuned for AWS free tier. To upgrade, set `db_instance_class = "db.t3.medium"`, `db_multi_az = true`, `performance_insights_enabled = true`, `db_deletion_protection = true`, and `db_backup_retention_days = 7`.

---

## Updating App Code

When you change anything under `app/`, run these two steps:

**1 — Upload new code to S3:**
```bash
cd environments/prod          # or dev
terraform apply -var-file=terraform.tfvars
# Terraform detects the file hash changed and re-uploads the tarball automatically
```

**2 — Push to the running instance:**
```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=threetier-prod-app-asg" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text --region us-east-1)

CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "aws s3 cp s3://threetier-prod-artifacts-069176179632/app/app-latest.tar.gz /tmp/app.tar.gz --region us-east-1",
    "tar -xzf /tmp/app.tar.gz -C /opt/app",
    "chown -R appuser:appuser /opt/app",
    "pip3 install -q -r /opt/app/requirements.txt",
    "systemctl restart app"
  ]' \
  --region us-east-1 --query "Command.CommandId" --output text)

sleep 20
aws ssm list-command-invocations --command-id "$CMD_ID" \
  --details --query "CommandInvocations[0].Status" --output text --region us-east-1
```

**Alternative — terminate and let ASG replace (cleanest):**
```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region us-east-1
# New instance boots fresh, downloads latest tarball from S3 automatically
# Wait ~3 minutes, then check ALB target health
```

> If `jenkins_url` is set in tfvars, step 2 happens automatically via Jenkins on every `terraform apply`.

---

## Jenkins CI/CD Pipeline

The `pipelinescript` supports four actions, selectable as a build parameter:

| Action    | What it does                                                        |
|-----------|---------------------------------------------------------------------|
| `plan`    | `terraform plan` — shows changes, no apply                          |
| `apply`   | Full infra + app deploy via Terraform                               |
| `destroy` | Tears down all resources (requires manual confirmation in UI)       |
| `deploy`  | Pushes updated app code to running instances via **SSM Run Command** without touching infrastructure |

### Jenkins setup

1. Add AWS credentials in Jenkins → **Manage Credentials** with IDs `accesskey` and `secretkey`.
2. Create a new Pipeline job pointing to this repo, using `pipelinescript` as the pipeline definition.
3. Run with **`ENVIRONMENT=dev ACTION=apply`** for initial deployment.

### Enabling auto-trigger from Terraform

Uncomment the Jenkins variables in `terraform.tfvars`:

```hcl
jenkins_url      = "http://your-jenkins-server:8080"
jenkins_job_name = "three-tier-deploy"
jenkins_user     = "admin"
jenkins_token    = "your-api-token"
```

When `app/` files change and you run `terraform apply`, Terraform packages and uploads the new app to S3, then calls the Jenkins API to trigger a `deploy` run — Jenkins uses SSM Run Command to update all ASG instances in parallel.

---

## Security Design

| Control                        | Implementation                                              |
|--------------------------------|-------------------------------------------------------------|
| No SSH keys                    | EC2 access via SSM Session Manager only                     |
| IMDSv2 enforced                | `http_tokens = "required"` in launch template               |
| No public IPs on app instances | `associate_public_ip_address = false`                       |
| DB credentials never in code   | `random_password` → stored in Secrets Manager, fetched at runtime |
| RDS encryption at rest         | KMS customer-managed key with annual rotation               |
| DB subnets fully isolated      | Explicit route table with no default route                  |
| SGs chained by reference       | No CIDR-based rules between tiers; only SG-to-SG references |
| S3 buckets locked down         | All public access blocked; KMS-SSE; versioning enabled      |
| Least-privilege IAM            | Separate policies per action, scoped to specific ARNs       |
| State encrypted                | S3 backend with KMS-SSE + DynamoDB locking                  |

---

## Accessing App Instances (SSM)

```bash
# List running instances in the ASG
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=threetier-dev-app-asg" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text

# Open an interactive shell — no bastion, no SSH key needed
aws ssm start-session --target i-0abc1234567890def
```

---

## Fetching DB Credentials

```bash
# Get the secret name from Terraform output
SECRET=$(terraform -chdir=environments/dev output -raw db_secret_name)

# Fetch and pretty-print credentials
aws secretsmanager get-secret-value \
  --secret-id "$SECRET" \
  --query SecretString \
  --output text | python3 -m json.tool
```

---

## Important: What NOT to Commit

- `terraform.tfstate` / `*.tfstate.backup` — managed by the S3 backend
- Real credentials in `.tfvars` or any file — use Secrets Manager / Jenkins credentials
- AWS access keys in source code

The `.gitignore` in this repo covers all of the above.

---

## Cleanup

```bash
# Destroy dev (safe — no deletion protection)
cd environments/dev
terraform destroy -var-file=terraform.tfvars

# Destroy prod (deletion protection is ON — disable it first)
cd environments/prod
# Set db_deletion_protection = false and alb_deletion_protection = false in terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform destroy -var-file=terraform.tfvars
```

---

## Module Reference

### `modules/vpc`
Creates the VPC, all six subnets, IGW, one NAT Gateway per AZ, and three separate route tables. DB subnets have no default route.

### `modules/security`
Three security groups linked entirely by SG references — no CIDR-based cross-tier rules. ALB SG is the only one that accepts `0.0.0.0/0`.

### `modules/alb`
Internet-facing Application Load Balancer in public subnets. Target group on port 8080 with `/health` health checks. Stickiness disabled by default.

### `modules/compute`
IAM role with SSM + scoped S3 + scoped Secrets Manager policies. Launch template enforces IMDSv2 and no public IP. ASG with rolling instance refresh, scale-up at 75% CPU, scale-down at 20% CPU. Optional Jenkins trigger via `null_resource`.

### `modules/rds`
Customer-managed KMS key with rotation. `random_password` generates a 20-character password stored in Secrets Manager (never in state as plaintext after initial write). Multi-AZ, gp3 storage, enhanced monitoring, Performance Insights, slow-query logs to CloudWatch.
