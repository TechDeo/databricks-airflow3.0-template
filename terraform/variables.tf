# Environment Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "airflow"
}

# AWS Region
variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

# Your IP address (for SSH and Airflow UI access)
variable "my_ip" {
  description = "Your IP address in CIDR format (e.g., 203.0.113.45/32)"
  type        = string
}

# SSH Key Name (must already exist in AWS)
variable "key_name" {
  description = "Name of your SSH key pair in AWS"
  type        = string
}

# EC2 Instance Type
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

# ECR Repository Name
variable "ecr_repository_name" {
  description = "Name of ECR repository for Airflow images"
  default     = "my-dags"
}

# S3 Bucket (optional)
variable "create_s3_bucket" {
  description = "Create S3 bucket for data assets? (needed for produce_data_assets DAG)"
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "S3 bucket name (only if create_s3_bucket = true)"
  default     = ""
}

# Secrets Manager Configuration
variable "create_secrets" {
  description = "Create AWS Secrets Manager secrets for sensitive data"
  type        = bool
  default     = true
}

variable "databricks_host" {
  description = "Databricks workspace URL (optional, can be set in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "databricks_token" {
  description = "Databricks access token (optional, can be set in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "airflow_admin_password" {
  description = "Airflow admin password (optional, can be set in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password (optional, can be set in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

# Common Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "airflow"
    ManagedBy = "terraform"
  }
}
