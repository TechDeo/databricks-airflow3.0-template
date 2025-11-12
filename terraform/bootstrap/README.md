# Terraform Bootstrap

This directory contains the bootstrap configuration to create the S3 bucket and DynamoDB table for Terraform state management.

## Usage

**Run this ONCE before using the S3 backend:**

```bash
cd terraform/bootstrap

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (creates S3 bucket and DynamoDB table)
terraform apply
```

After this completes, it will output the backend configuration. Copy that configuration to your `terraform/backend.tf` file.

## What This Creates

1. **S3 Bucket** - Stores Terraform state files
   - Versioning enabled (state history)
   - Encryption enabled (AES256)
   - Public access blocked

2. **DynamoDB Table** - Prevents concurrent state modifications
   - Pay-per-request billing
   - Automatic state locking

## Important Notes

- This bootstrap config uses **local state** (stored in `terraform.tfstate`)
- Keep the `terraform.tfstate` file in this directory safe (or commit to git)
- This is a one-time setup - you won't need to run this again unless you want to recreate the backend infrastructure
