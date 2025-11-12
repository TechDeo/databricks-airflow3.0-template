# EC2 Instance
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.airflow.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.airflow.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.airflow.public_ip}"
}

output "airflow_url" {
  description = "URL to access Airflow UI"
  value       = "http://${aws_instance.airflow.public_ip}:8080"
}

# ECR
output "ecr_registry" {
  description = "ECR registry URL"
  value       = split("/", aws_ecr_repository.airflow.repository_url)[0]
}

output "ecr_repository" {
  description = "ECR repository name"
  value       = aws_ecr_repository.airflow.name
}

output "ecr_repository_url" {
  description = "Full ECR repository URL"
  value       = aws_ecr_repository.airflow.repository_url
}

# S3
output "s3_bucket" {
  description = "S3 bucket name (if created)"
  value       = var.create_s3_bucket ? aws_s3_bucket.data[0].id : "Not created"
}

# Secrets Manager
output "secrets_manager_arns" {
  description = "ARNs of created secrets"
  value = var.create_secrets ? {
    databricks_host        = aws_secretsmanager_secret.databricks_host[0].arn
    databricks_token       = aws_secretsmanager_secret.databricks_token[0].arn
    airflow_admin_password = aws_secretsmanager_secret.airflow_admin_password[0].arn
    postgres_password      = aws_secretsmanager_secret.postgres_password[0].arn
  } : {}
}

output "secrets_manager_names" {
  description = "Names of created secrets"
  value = var.create_secrets ? {
    databricks_host        = aws_secretsmanager_secret.databricks_host[0].name
    databricks_token       = aws_secretsmanager_secret.databricks_token[0].name
    airflow_admin_password = aws_secretsmanager_secret.airflow_admin_password[0].name
    postgres_password      = aws_secretsmanager_secret.postgres_password[0].name
  } : {}
}

# Environment Info
output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

# For .env file
output "env_values" {
  description = "Environment variables for .env file"
  value = <<-EOT

    Add to your .env file:
    ENVIRONMENT=${var.environment}
    ECR_REGISTRY=${split("/", aws_ecr_repository.airflow.repository_url)[0]}
    ECR_REPO=${aws_ecr_repository.airflow.name}
    AWS_DEFAULT_REGION=${var.aws_region}
    ${var.create_s3_bucket ? "S3_BUCKET=${aws_s3_bucket.data[0].id}" : "# S3 not created"}

    Secrets Manager:
    ${var.create_secrets ? "DATABRICKS_HOST_SECRET=${aws_secretsmanager_secret.databricks_host[0].name}" : ""}
    ${var.create_secrets ? "DATABRICKS_TOKEN_SECRET=${aws_secretsmanager_secret.databricks_token[0].name}" : ""}
    ${var.create_secrets ? "AIRFLOW_PASSWORD_SECRET=${aws_secretsmanager_secret.airflow_admin_password[0].name}" : ""}
    ${var.create_secrets ? "POSTGRES_PASSWORD_SECRET=${aws_secretsmanager_secret.postgres_password[0].name}" : ""}
  EOT
}
