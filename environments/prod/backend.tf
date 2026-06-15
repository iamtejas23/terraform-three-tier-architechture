terraform {
  backend "s3" {
    bucket         = "threetier-tf-state-069176179632"
    key            = "three-tier/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
