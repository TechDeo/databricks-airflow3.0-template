# Terraform Infrastructure for Airflow on EC2

This Terraform configuration automatically creates all AWS resources needed to run Airflow on EC2.

## What Gets Created

- **ECR Repository** - Docker image registry for Airflow
- **S3 Bucket** (optional) - Data storage for DAGs
- **IAM Role** - EC2 permissions for ECR and S3
- **Security Group** - Network access control (ports 22, 8080)
- **EC2 Instance** - Server running Docker and Docker Compose

## Prerequisites

1. **Terraform installed** (v1.0+)
   ```bash
   # Check version
   terraform version

   # Install if needed (macOS)
   brew install terraform

   # Install if needed (Linux)
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **AWS CLI configured**
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Key, and region
   ```

3. **SSH Key Pair created in AWS**
   ```bash
   # Create new key pair
   aws ec2 create-key-pair \
     --key-name airflow-key \
     --query 'KeyMaterial' \
     --output text > airflow-key.pem

   # Set permissions
   chmod 400 airflow-key.pem
   ```

## Quick Start

### 1. Configure Variables

```bash
cd terraform

# Copy example config
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Minimum required changes:**
```hcl
key_name = "airflow-key"  # Your SSH key name

# IMPORTANT: For security, restrict to your IP
allowed_ssh_cidr     = "YOUR.IP.ADDRESS/32"
allowed_airflow_cidr = "YOUR.IP.ADDRESS/32"
```

Get your IP address:
```bash
curl https://checkip.amazonaws.com
# Example output: 203.0.113.45
# Use: 203.0.113.45/32 in terraform.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and prepares Terraform.

### 3. Preview Changes

```bash
terraform plan
```

Review what will be created. You should see:
- 1 ECR repository
- 1 S3 bucket (if enabled)
- 1 IAM role + policies
- 1 Security group + rules
- 1 EC2 instance
- Total: ~10-15 resources

### 4. Create Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**This will take 2-3 minutes.**

### 5. Get Outputs

```bash
# View all outputs
terraform output

# View specific output
terraform output instance_public_ip
terraform output ecr_repository_url
terraform output ssh_command
```

### 6. SSH into EC2

```bash
# Use the SSH command from output
terraform output -raw ssh_command | bash

# Or manually
ssh -i airflow-key.pem ec2-user@<PUBLIC_IP>
```

## Configuration Options

### Instance Sizing

| Instance Type | vCPU | Memory | Monthly Cost | Recommended For |
|--------------|------|---------|--------------|-----------------|
| t3.small | 2 | 2 GB | ~$15 | Testing only |
| t3.medium | 2 | 4 GB | ~$30 | Development |
| t3.large | 2 | 8 GB | ~$60 | Production |
| t3.xlarge | 4 | 16 GB | ~$120 | High workload |

Change in `terraform.tfvars`:
```hcl
instance_type = "t3.medium"
```

### S3 Bucket (Optional)

**Do you need S3?**
- **YES** if you're using the `produce_data_assets` DAG (downloads and uploads data)
- **NO** if you're only triggering Databricks jobs

To disable S3:
```hcl
create_s3_bucket = false
```

### ECR Lifecycle Policy

Control how many images to keep (older ones are deleted):
```hcl
ecr_lifecycle_policy_count = 10  # Keep last 10 images
```

### Security Configuration

**⚠️ Important: Restrict access to your IP only!**

```hcl
# Single IP
allowed_ssh_cidr     = "203.0.113.45/32"
allowed_airflow_cidr = "203.0.113.45/32"

# IP range (e.g., office network)
allowed_ssh_cidr     = "203.0.113.0/24"
allowed_airflow_cidr = "203.0.113.0/24"

# Multiple IPs (use multiple security group rules - see main.tf)
```

## Important Outputs

After `terraform apply`, you'll get:

```bash
# ECR Registry URL (for .env file)
terraform output ecr_registry_url

# S3 Bucket Name (for .env file)
terraform output s3_bucket_name

# EC2 Public IP
terraform output instance_public_ip

# SSH Command
terraform output ssh_command

# Airflow UI URL
terraform output airflow_ui_url

# All values for .env file
terraform output env_file_variables

# GitHub secrets
terraform output github_secrets

# Next steps
terraform output next_steps
```

## After Terraform Apply

### 1. Wait for EC2 Setup

The EC2 instance runs a setup script automatically (`user_data.sh`). This installs Docker, Docker Compose, and AWS CLI.

Check progress:
```bash
# SSH into EC2
ssh -i airflow-key.pem ec2-user@<PUBLIC_IP>

# Watch setup log
tail -f /var/log/cloud-init-output.log

# Wait for "EC2 Setup Complete!" message
```

### 2. Clone Repository

```bash
git clone -b ec2-docker-compose \
  https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
cd airflow
```

### 3. Configure .env File

```bash
cp .env.example .env
vim .env
```

Use the values from Terraform outputs:
```bash
# Get values
cd ../terraform
terraform output env_file_variables

# Copy values to .env file
```

### 4. Deploy Airflow

```bash
cd ~/airflow
./manage_docker_compose.sh start
```

### 5. Access Airflow UI

```bash
# Get URL from Terraform
terraform output airflow_ui_url

# Open in browser
# http://<PUBLIC_IP>:8080
# Login: admin / admin
```

## Managing Infrastructure

### View Current State

```bash
terraform show
```

### Update Infrastructure

Edit `terraform.tfvars`, then:
```bash
terraform plan    # Preview changes
terraform apply   # Apply changes
```

### Destroy Infrastructure

**⚠️ Warning: This deletes everything!**

```bash
terraform destroy
```

Type `yes` when prompted.

**What gets deleted:**
- EC2 instance
- Security group
- IAM role and policies
- ECR repository (and all images!)
- S3 bucket (and all data!)

### Partial Destruction

To keep some resources:

```bash
# Remove specific resource
terraform destroy -target=aws_instance.airflow

# Or modify terraform.tfvars and apply
create_s3_bucket = false
terraform apply
```

## Cost Optimization

### Development Environment

```hcl
# terraform.tfvars
instance_type = "t3.small"    # Smallest for testing
create_s3_bucket = false      # Skip if not needed
```

**Monthly cost: ~$15-20**

### Stop/Start EC2 (Keep Everything Else)

```bash
# Stop instance (stops hourly charges)
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Start instance (when you need it)
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Get new IP after start
terraform refresh
terraform output instance_public_ip
```

### Use Spot Instances

For non-critical workloads, use spot instances (up to 90% savings).

Edit `main.tf`:
```hcl
resource "aws_spot_instance_request" "airflow" {
  # ... configuration ...
}
```

## Troubleshooting

### Terraform Errors

**Error: Key pair not found**
```bash
# List your key pairs
aws ec2 describe-key-pairs

# Create new one
aws ec2 create-key-pair --key-name airflow-key \
  --query 'KeyMaterial' --output text > airflow-key.pem
chmod 400 airflow-key.pem
```

**Error: CIDR block invalid**
```bash
# Check format: X.X.X.X/32 for single IP, X.X.X.X/24 for range
allowed_ssh_cidr = "203.0.113.45/32"  # Correct
allowed_ssh_cidr = "203.0.113.45"     # Wrong - missing /32
```

**Error: No default VPC**
```bash
# Check VPCs
aws ec2 describe-vpcs

# If no default VPC, create one or specify VPC in variables.tf
```

### Can't SSH into EC2

```bash
# Check security group allows your IP
terraform output security_group_id

# Your IP may have changed
curl https://checkip.amazonaws.com

# Update terraform.tfvars with new IP and apply
terraform apply
```

### Can't Access Airflow UI

```bash
# Check if Airflow is running on EC2
ssh -i airflow-key.pem ec2-user@<IP>
docker-compose ps

# Check security group allows port 8080
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id)
```

### EC2 Can't Pull from ECR

```bash
# Check IAM role is attached
terraform output instance_profile_name

# Test from EC2
ssh -i airflow-key.pem ec2-user@<IP>
aws ecr describe-repositories
# Should not get permission errors
```

### State Lock Errors

If Terraform crashes:
```bash
# Force unlock (use lock ID from error message)
terraform force-unlock <LOCK_ID>
```

## Advanced Configuration

### Use Existing VPC/Subnet

Edit `main.tf`:
```hcl
# Comment out default VPC data sources
# data "aws_vpc" "default" { ... }

# Add your VPC
data "aws_vpc" "main" {
  id = var.vpc_id
}
```

Add to `variables.tf`:
```hcl
variable "vpc_id" {
  description = "VPC ID to use"
  type        = string
}
```

### Add RDS for PostgreSQL

Add to `main.tf`:
```hcl
resource "aws_db_instance" "airflow" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  # ... more configuration ...
}
```

### Enable CloudWatch Monitoring

Add to `main.tf`:
```hcl
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    InstanceId = aws_instance.airflow.id
  }
}
```

## Files Structure

```
terraform/
├── README.md                    # This file
├── main.tf                      # Main resources (EC2, ECR, S3, IAM)
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── user_data.sh                 # EC2 initialization script
├── terraform.tfvars.example     # Example configuration
├── terraform.tfvars             # Your configuration (gitignored)
└── .gitignore                   # Git ignore rules
```

## Best Practices

1. **Never commit `terraform.tfvars`** - Contains sensitive info
2. **Use remote state** for team collaboration (S3 + DynamoDB)
3. **Restrict CIDR blocks** to your IP, not 0.0.0.0/0
4. **Use separate environments** (dev/staging/prod)
5. **Tag all resources** for cost tracking
6. **Enable encryption** on EBS volumes and S3
7. **Regular backups** of Terraform state

## Remote State (Team Collaboration)

For teams, store state in S3:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "airflow/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Create backend resources:
```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Support

For issues with:
- **Terraform configuration**: Check this README
- **AWS resources**: See [AWS_SETUP_GUIDE.md](../AWS_SETUP_GUIDE.md)
- **Airflow deployment**: See [README-EC2.md](../README-EC2.md)

## License

This Terraform configuration is provided as-is for educational purposes.
