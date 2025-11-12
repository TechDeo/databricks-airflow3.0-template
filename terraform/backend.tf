# Terraform Backend Configuration
# This stores state in S3 with DynamoDB locking
#
# Before using this:
# 1. Run terraform in bootstrap/ directory first to create the S3 bucket and DynamoDB table
# 2. Update the bucket name below if you changed it
#
# To use different environments:
# terraform workspace new dev
# terraform workspace new staging
# terraform workspace new prod
# terraform workspace select dev

terraform {
  backend "s3" {
    bucket         = "airflow-terraform-state-adeola"
    key            = "airflow/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "airflow-terraform-locks"
    encrypt        = true

    # Optional: Use workspace-based keys for environment isolation
    # This will create separate state files: airflow/dev/terraform.tfstate, airflow/prod/terraform.tfstate
    workspace_key_prefix = "airflow"
  }
}
