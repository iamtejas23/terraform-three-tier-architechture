# Run `bootstrap/` first to create this bucket and DynamoDB table,
# then fill in your actual bucket name below.
terraform {
  backend "s3" {
    bucket         = "REPLACE-WITH-YOUR-STATE-BUCKET-NAME"
    key            = "three-tier/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
