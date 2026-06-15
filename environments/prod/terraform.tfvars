project     = "threetier"
environment = "prod"
aws_region  = "us-east-1"
owner       = "iamtejas23"

# Prod VPC uses 10.1.0.0/16 to avoid overlap with dev (10.0.0.0/16)
vpc_cidr                 = "10.1.0.0/16"
availability_zones       = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs      = ["10.1.1.0/24", "10.1.2.0/24"]
private_app_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
private_db_subnet_cidrs  = ["10.1.21.0/24", "10.1.22.0/24"]

alb_deletion_protection = true

# Compute — Amazon Linux 2023 us-east-1 (verify latest AMI before apply)
ami_id        = "ami-0230bd60aa48260c6"
instance_type = "t3.small"

asg_min_size         = 2
asg_max_size         = 6
asg_desired_capacity = 2

# RDS (prod: Multi-AZ, medium instance, deletion protection ON)
db_name                     = "appdb"
db_username                 = "appadmin"
db_instance_class           = "db.t3.micro"
db_allocated_storage        = 20
db_max_allocated_storage    = 20
db_multi_az                 = false
db_deletion_protection      = false
db_backup_retention_days     = 1
secret_recovery_window_days  = 7
performance_insights_enabled = false

# Jenkins
# jenkins_url      = "http://your-jenkins-server:8080"
# jenkins_job_name = "three-tier-deploy"
# jenkins_user     = "admin"
# jenkins_token    = "your-api-token"
