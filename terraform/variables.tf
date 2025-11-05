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
