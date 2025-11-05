# AWS Region
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# Project name (used for naming resources)
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "airflow"
}

# Environment (dev, staging, prod)
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# EC2 Instance Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "key_name" {
  description = "SSH key pair name (must already exist in AWS)"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into EC2 instance"
  type        = string
  default     = "0.0.0.0/0" # WARNING: Change this to your IP for security!
}

variable "allowed_airflow_cidr" {
  description = "CIDR block allowed to access Airflow UI (port 8080)"
  type        = string
  default     = "0.0.0.0/0" # WARNING: Change this to your IP for security!
}

# ECR Configuration
variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "my-dags"
}

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "ecr_lifecycle_policy_count" {
  description = "Number of images to keep in ECR (older images will be deleted)"
  type        = number
  default     = 10
}

# S3 Configuration
variable "create_s3_bucket" {
  description = "Whether to create S3 bucket for data assets (needed for produce_data_assets DAG)"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Name of S3 bucket for data assets (must be globally unique, leave empty for auto-generated)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
