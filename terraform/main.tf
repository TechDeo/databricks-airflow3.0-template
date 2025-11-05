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

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
  }
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Default subnet
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = data.aws_availability_zones.available.names[0]
}

#######################
# ECR Repository
#######################

resource "aws_ecr_repository" "airflow" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "airflow" {
  repository = aws_ecr_repository.airflow.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.ecr_lifecycle_policy_count} images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = var.ecr_lifecycle_policy_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

#######################
# S3 Bucket (Optional)
#######################

resource "random_id" "bucket_suffix" {
  count       = var.create_s3_bucket && var.s3_bucket_name == "" ? 1 : 0
  byte_length = 4
}

locals {
  s3_bucket_name = var.create_s3_bucket ? (
    var.s3_bucket_name != "" ? var.s3_bucket_name : "data-platform-${random_id.bucket_suffix[0].hex}"
  ) : ""
}

resource "aws_s3_bucket" "data" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_name

  tags = {
    Name = "${var.project_name}-data"
  }
}

resource "aws_s3_bucket_versioning" "data" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.data[0].id

  versioning_configuration {
    status = "Disabled"
  }
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
# IAM Role for EC2
#######################

# Trust policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Role
resource "aws_iam_role" "airflow_ec2" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# ECR Read Policy
data "aws_iam_policy_document" "ecr_read" {
  statement {
    sid    = "ECRRead"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:ListImages"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_read" {
  name        = "${var.project_name}-ecr-read-policy"
  description = "Allow EC2 to pull images from ECR"
  policy      = data.aws_iam_policy_document.ecr_read.json
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.airflow_ec2.name
  policy_arn = aws_iam_policy.ecr_read.arn
}

# S3 Access Policy (only if S3 bucket is created)
data "aws_iam_policy_document" "s3_access" {
  count = var.create_s3_bucket ? 1 : 0

  statement {
    sid    = "S3ListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.data[0].arn
    ]
  }

  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.data[0].arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  count       = var.create_s3_bucket ? 1 : 0
  name        = "${var.project_name}-s3-access-policy"
  description = "Allow EC2 to access S3 bucket for data assets"
  policy      = data.aws_iam_policy_document.s3_access[0].json
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  count      = var.create_s3_bucket ? 1 : 0
  role       = aws_iam_role.airflow_ec2.name
  policy_arn = aws_iam_policy.s3_access[0].arn
}

# Instance Profile
resource "aws_iam_instance_profile" "airflow_ec2" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.airflow_ec2.name

  tags = {
    Name = "${var.project_name}-ec2-instance-profile"
  }
}

#######################
# Security Group
#######################

resource "aws_security_group" "airflow" {
  name        = "${var.project_name}-sg"
  description = "Security group for Airflow EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# SSH access
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
  security_group_id = aws_security_group.airflow.id
  description       = "SSH access"
}

# Airflow UI access
resource "aws_security_group_rule" "airflow_ui" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_airflow_cidr]
  security_group_id = aws_security_group.airflow.id
  description       = "Airflow UI access"
}

# Outbound access (all)
resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.airflow.id
  description       = "Allow all outbound traffic"
}

#######################
# EC2 Instance
#######################

resource "aws_instance" "airflow" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.airflow.id]
  iam_instance_profile   = aws_iam_instance_profile.airflow_ec2.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
  })

  tags = {
    Name = "${var.project_name}-server"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}
