# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.airflow.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.airflow.name
}

output "ecr_registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = aws_ecr_repository.airflow.registry_id
}

output "ecr_registry_url" {
  description = "ECR registry URL (format: account-id.dkr.ecr.region.amazonaws.com)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for data assets"
  value       = var.create_s3_bucket ? aws_s3_bucket.data[0].id : "Not created"
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = var.create_s3_bucket ? aws_s3_bucket.data[0].arn : "Not created"
}

# IAM Outputs
output "iam_role_name" {
  description = "Name of the IAM role for EC2"
  value       = aws_iam_role.airflow_ec2.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2"
  value       = aws_iam_role.airflow_ec2.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.airflow_ec2.name
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.airflow.id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = aws_security_group.airflow.name
}

# EC2 Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.airflow.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.airflow.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.airflow.private_ip
}

output "instance_type" {
  description = "Instance type of the EC2 instance"
  value       = aws_instance.airflow.instance_type
}

# Connection Information
output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.airflow.public_ip}"
}

output "airflow_ui_url" {
  description = "URL to access Airflow UI"
  value       = "http://${aws_instance.airflow.public_ip}:8080"
}

# Summary for .env file
output "env_file_variables" {
  description = "Variables to add to your .env file"
  value = <<-EOT
    # Add these to your .env file:
    ECR_REGISTRY=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
    ECR_REPO=${aws_ecr_repository.airflow.name}
    AWS_DEFAULT_REGION=${var.aws_region}
    ${var.create_s3_bucket ? "S3_BUCKET=${aws_s3_bucket.data[0].id}" : "# S3_BUCKET not created"}
  EOT
}

# GitHub Secrets
output "github_secrets" {
  description = "GitHub secrets to configure"
  value = <<-EOT
    # Add these GitHub secrets:
    AWS_ACCESS_KEY_ID=<your-access-key>
    AWS_SECRET_ACCESS_KEY=<your-secret-key>
    ECR_REGISTRY=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
  EOT
}

# Next Steps
output "next_steps" {
  description = "Next steps to deploy Airflow"
  value = <<-EOT
    ========================================
    🎉 Infrastructure Created Successfully!
    ========================================

    1. SSH into EC2 instance:
       ${format("ssh -i %s.pem ec2-user@%s", var.key_name, aws_instance.airflow.public_ip)}

    2. The setup script is already running via user_data.
       Check progress: tail -f /var/log/cloud-init-output.log

    3. Once setup completes, clone the repository:
       git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
       cd airflow

    4. Configure .env file:
       cp .env.example .env
       # Add these values:
       ECR_REGISTRY=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
       ECR_REPO=${aws_ecr_repository.airflow.name}
       ${var.create_s3_bucket ? "S3_BUCKET=${aws_s3_bucket.data[0].id}" : ""}

    5. Deploy Airflow:
       ./manage_docker_compose.sh start

    6. Access Airflow UI:
       ${format("http://%s:8080", aws_instance.airflow.public_ip)}
       Username: admin
       Password: admin (change this!)

    ========================================
  EOT
}
