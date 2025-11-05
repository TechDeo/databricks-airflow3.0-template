# EC2 Instance
output "instance_public_ip" {
  value = aws_instance.airflow.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.airflow.public_ip}"
}

output "airflow_url" {
  value = "http://${aws_instance.airflow.public_ip}:8080"
}

# ECR
output "ecr_registry" {
  value = split("/", aws_ecr_repository.airflow.repository_url)[0]
}

output "ecr_repository" {
  value = aws_ecr_repository.airflow.name
}

# S3
output "s3_bucket" {
  value = var.create_s3_bucket ? aws_s3_bucket.data[0].id : "Not created"
}

# For .env file
output "env_values" {
  value = <<-EOT

    Add to your .env file:
    ECR_REGISTRY=${split("/", aws_ecr_repository.airflow.repository_url)[0]}
    ECR_REPO=${aws_ecr_repository.airflow.name}
    AWS_DEFAULT_REGION=${var.aws_region}
    ${var.create_s3_bucket ? "S3_BUCKET=${aws_s3_bucket.data[0].id}" : "# S3 not created"}
  EOT
}
