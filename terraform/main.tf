terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#######################
# ECR Repository
#######################
resource "aws_ecr_repository" "airflow" {
  name = var.ecr_repository_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-ecr"
      Environment = var.environment
    }
  )
}

#######################
# S3 Bucket (Optional)
#######################
resource "aws_s3_bucket" "data" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-data"
      Environment = var.environment
    }
  )
}

resource "aws_s3_bucket_public_access_block" "data" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.data[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#######################
# AWS Secrets Manager
#######################
resource "aws_secretsmanager_secret" "databricks_host" {
  count       = var.create_secrets ? 1 : 0
  name        = "${var.project_name}-${var.environment}-databricks-host"
  description = "Databricks workspace URL for ${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-databricks-host"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "databricks_host" {
  count         = var.create_secrets && var.databricks_host != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.databricks_host[0].id
  secret_string = var.databricks_host
}

resource "aws_secretsmanager_secret" "databricks_token" {
  count       = var.create_secrets ? 1 : 0
  name        = "${var.project_name}-${var.environment}-databricks-token"
  description = "Databricks access token for ${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-databricks-token"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "databricks_token" {
  count         = var.create_secrets && var.databricks_token != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.databricks_token[0].id
  secret_string = var.databricks_token
}

resource "aws_secretsmanager_secret" "airflow_admin_password" {
  count       = var.create_secrets ? 1 : 0
  name        = "${var.project_name}-${var.environment}-airflow-admin-password"
  description = "Airflow admin password for ${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-airflow-admin-password"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "airflow_admin_password" {
  count         = var.create_secrets && var.airflow_admin_password != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.airflow_admin_password[0].id
  secret_string = var.airflow_admin_password
}

resource "aws_secretsmanager_secret" "postgres_password" {
  count       = var.create_secrets ? 1 : 0
  name        = "${var.project_name}-${var.environment}-postgres-password"
  description = "PostgreSQL password for ${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-postgres-password"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "postgres_password" {
  count         = var.create_secrets && var.postgres_password != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.postgres_password[0].id
  secret_string = var.postgres_password
}

#######################
# IAM Role for EC2
#######################
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-ec2-role"
      Environment = var.environment
    }
  )
}

# Policy: Pull and Push to ECR
resource "aws_iam_role_policy" "ecr" {
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ]
      Resource = "*"
    }]
  })
}

# Policy: Access S3 (only if bucket created)
resource "aws_iam_role_policy" "s3" {
  count = var.create_s3_bucket ? 1 : 0
  role  = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = [
        aws_s3_bucket.data[0].arn,
        "${aws_s3_bucket.data[0].arn}/*"
      ]
    }]
  })
}

# Policy: Access Secrets Manager
resource "aws_iam_role_policy" "secrets_manager" {
  count = var.create_secrets ? 1 : 0
  role  = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        aws_secretsmanager_secret.databricks_host[0].arn,
        aws_secretsmanager_secret.databricks_token[0].arn,
        aws_secretsmanager_secret.airflow_admin_password[0].arn,
        aws_secretsmanager_secret.postgres_password[0].arn
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-ec2-profile"
      Environment = var.environment
    }
  )
}

#######################
# Security Group
#######################
resource "aws_security_group" "airflow" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Allow SSH and Airflow UI access for ${var.environment}"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Airflow UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Airflow HTTP (port 80)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Airflow HTTPS (port 443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-sg"
      Environment = var.environment
    }
  )
}

#######################
# EC2 Instance
#######################
resource "aws_instance" "airflow" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.airflow.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user_data.sh")

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-server"
      Environment = var.environment
    }
  )
}
