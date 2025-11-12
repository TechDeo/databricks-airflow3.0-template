variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (must be globally unique)"
  type        = string
  default     = "airflow-terraform-state-adeola"
}

variable "terraform_locks_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "airflow-terraform-locks"
}
