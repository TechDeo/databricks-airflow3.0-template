# AWS Setup Guide for Airflow on EC2

This guide walks you through all the AWS resources and secrets you need to set up before deploying Airflow on EC2.

## Overview

You'll need to set up:
1. **AWS ECR** - Docker image registry
2. **S3 Bucket** - For data assets (used by DAGs)
3. **EC2 Instance** - To run Airflow
4. **IAM Role** - For EC2 to access AWS services
5. **Security Group** - Network access control
6. **GitHub Secrets** - For CI/CD pipeline
7. **Databricks** - Connection details

---

## 1. AWS ECR Repository Setup

### Create ECR Repository

**Option A: AWS Console**
1. Go to **AWS Console** → **ECR** (Elastic Container Registry)
2. Click **"Create repository"**
3. Configure:
   - **Repository name**: `my-dags`
   - **Visibility**: Private
   - **Tag immutability**: Disabled (for easier development)
   - **Scan on push**: Enabled (optional, for security)
4. Click **"Create repository"**
5. **Note the repository URI**: `123456789012.dkr.ecr.us-east-1.amazonaws.com/my-dags`

**Option B: AWS CLI**
```bash
# Set your AWS region
export AWS_REGION=us-east-1

# Create ECR repository
aws ecr create-repository \
  --repository-name my-dags \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true

# Get the repository URI
aws ecr describe-repositories \
  --repository-names my-dags \
  --region $AWS_REGION \
  --query 'repositories[0].repositoryUri' \
  --output text
```

### Configure Lifecycle Policy (Optional but Recommended)

Keep only the last 10 images to save costs:

```bash
aws ecr put-lifecycle-policy \
  --repository-name my-dags \
  --region $AWS_REGION \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }]
  }'
```

### Get ECR Registry URL

```bash
# Format: <account-id>.dkr.ecr.<region>.amazonaws.com
aws sts get-caller-identity --query Account --output text
# Example output: 223340170015

# Your ECR registry will be:
# 223340170015.dkr.ecr.us-east-1.amazonaws.com
```

---

## 2. S3 Bucket Setup

### Create S3 Bucket for Data Assets

The DAG `produce_data_assets.py` uses S3 to store data files.

**Option A: AWS Console**
1. Go to **S3** → **Create bucket**
2. Configure:
   - **Bucket name**: `data-platform-adeola` (or your preferred name, must be globally unique)
   - **Region**: `us-east-1` (or your preferred region)
   - **Block Public Access**: Keep all enabled (security best practice)
   - **Versioning**: Disabled (or enable if you want history)
3. Click **"Create bucket"**

**Option B: AWS CLI**
```bash
export S3_BUCKET=data-platform-adeola
export AWS_REGION=us-east-1

# Create bucket
aws s3 mb s3://$S3_BUCKET --region $AWS_REGION

# Verify
aws s3 ls
```

### Create Folder Structure (Optional)

```bash
# Create folders for data
aws s3api put-object --bucket $S3_BUCKET --key raw/
aws s3api put-object --bucket $S3_BUCKET --key processed/
```

---

## 3. IAM Role for EC2

Create an IAM role that allows your EC2 instance to access ECR, S3, and other AWS services without storing credentials.

### Create IAM Role

**Option A: AWS Console**
1. Go to **IAM** → **Roles** → **Create role**
2. Select **AWS service** → **EC2**
3. Click **Next**
4. Attach these policies:
   - `AmazonEC2ContainerRegistryReadOnly` (to pull from ECR)
   - `AmazonS3FullAccess` (for S3 access - or create custom policy for specific bucket)
5. **Role name**: `AirflowEC2Role`
6. Click **Create role**

**Option B: AWS CLI**

First, create a trust policy file:
```bash
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create the role:
```bash
# Create the role
aws iam create-role \
  --role-name AirflowEC2Role \
  --assume-role-policy-document file://trust-policy.json

# Attach ECR read-only policy
aws iam attach-role-policy \
  --role-name AirflowEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Attach S3 full access (or create custom policy)
aws iam attach-role-policy \
  --role-name AirflowEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name AirflowEC2InstanceProfile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name AirflowEC2InstanceProfile \
  --role-name AirflowEC2Role
```

### Custom S3 Policy (More Secure)

Instead of `AmazonS3FullAccess`, create a custom policy for your specific bucket:

```bash
cat > s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::data-platform-adeola"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::data-platform-adeola/*"
    }
  ]
}
EOF

# Create and attach custom policy
aws iam create-policy \
  --policy-name AirflowS3AccessPolicy \
  --policy-document file://s3-policy.json

# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach the custom policy
aws iam attach-role-policy \
  --role-name AirflowEC2Role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AirflowS3AccessPolicy
```

---

## 4. Security Group for EC2

Create a security group that allows SSH and Airflow UI access.

**Option A: AWS Console**
1. Go to **EC2** → **Security Groups** → **Create security group**
2. Configure:
   - **Name**: `airflow-sg`
   - **Description**: `Security group for Airflow on EC2`
   - **VPC**: Select your default VPC (or your preferred VPC)
3. **Inbound rules**:
   - **SSH**: Type `SSH`, Port `22`, Source `My IP` (or specific IP range)
   - **HTTP**: Type `Custom TCP`, Port `8080`, Source `My IP` (for Airflow UI)
4. **Outbound rules**: Leave default (all traffic)
5. Click **Create security group**

**Option B: AWS CLI**
```bash
# Get your default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)

# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name airflow-sg \
  --description "Security group for Airflow on EC2" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

echo "Security Group ID: $SG_ID"

# Get your current IP address
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Add SSH rule (port 22) - only from your IP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32

# Add Airflow UI rule (port 8080) - only from your IP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr ${MY_IP}/32

# View the security group
aws ec2 describe-security-groups --group-ids $SG_ID
```

**Security Note**: For production, consider:
- Using a VPN or bastion host instead of exposing SSH
- Using an Application Load Balancer with HTTPS for Airflow UI
- Restricting access to corporate IP ranges only

---

## 5. Launch EC2 Instance

### Choose Instance Type

Recommended specifications:
- **Development**: `t3.medium` (2 vCPU, 4 GB RAM) - ~$30/month
- **Production**: `t3.large` (2 vCPU, 8 GB RAM) - ~$60/month
- **High workload**: `t3.xlarge` (4 vCPU, 16 GB RAM) - ~$120/month

### Launch Instance

**Option A: AWS Console**
1. Go to **EC2** → **Instances** → **Launch Instance**
2. Configure:
   - **Name**: `airflow-server`
   - **AMI**: Amazon Linux 2023 (or Amazon Linux 2)
   - **Instance type**: `t3.medium`
   - **Key pair**: Select existing or create new SSH key pair
   - **Network settings**:
     - **VPC**: Default VPC
     - **Subnet**: Any availability zone
     - **Auto-assign public IP**: Enable
     - **Security group**: Select `airflow-sg`
   - **IAM instance profile**: Select `AirflowEC2InstanceProfile`
   - **Storage**: 20 GB gp3 (general purpose SSD)
3. Click **Launch instance**
4. **Note the Public IP address** once instance is running

**Option B: AWS CLI**
```bash
# Get the latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "Using AMI: $AMI_ID"

# Get default subnet
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[0].SubnetId' \
  --output text)

# Launch instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name your-key-pair-name \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --iam-instance-profile Name=AirflowEC2InstanceProfile \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":20,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=airflow-server}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instance is running at: $PUBLIC_IP"
echo "SSH command: ssh -i your-key.pem ec2-user@$PUBLIC_IP"
```

---

## 6. GitHub Secrets Configuration

For the CI/CD pipeline to work, you need to configure GitHub secrets.

### Required GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

1. **`AWS_ACCESS_KEY_ID`**
   - Your AWS access key ID
   - Get it from: AWS Console → IAM → Users → Security credentials

2. **`AWS_SECRET_ACCESS_KEY`**
   - Your AWS secret access key
   - Get it from: AWS Console → IAM → Users → Security credentials

3. **`AWS_SESSION_TOKEN`** (optional, only if using temporary credentials)
   - Leave empty if using permanent credentials
   - Required if using AWS SSO or temporary credentials

4. **`ECR_REGISTRY`**
   - Format: `<account-id>.dkr.ecr.<region>.amazonaws.com`
   - Example: `223340170015.dkr.ecr.us-east-1.amazonaws.com`
   - Get from: `aws sts get-caller-identity --query Account --output text`

### Get AWS Credentials

**If you don't have AWS credentials yet:**

```bash
# Option 1: Create IAM user for CI/CD (recommended for production)
aws iam create-user --user-name github-actions-user

# Attach ECR push policy
cat > ecr-push-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
EOF

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-policy \
  --policy-name GitHubActionsECRPush \
  --policy-document file://ecr-push-policy.json

aws iam attach-user-policy \
  --user-name github-actions-user \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsECRPush

# Create access key
aws iam create-access-key --user-name github-actions-user
```

Copy the `AccessKeyId` and `SecretAccessKey` from the output and add them to GitHub secrets.

**Option 2: Use your own credentials (for development)**
```bash
# View your credentials (if configured)
cat ~/.aws/credentials
```

### Add Secrets to GitHub

```bash
# Using GitHub CLI (if installed)
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set ECR_REGISTRY
```

Or manually through the GitHub web interface.

---

## 7. Databricks Configuration

### Get Databricks Details

You need:
1. **Databricks Workspace URL**
   - Example: `https://your-workspace.cloud.databricks.com`
   - Find in: Databricks Console → URL in browser

2. **Databricks Personal Access Token**
   - Go to: Databricks → User Settings → Access Tokens → Generate New Token
   - **Name**: `airflow-access`
   - **Lifetime**: 90 days (or longer)
   - **Copy the token** - you won't see it again!

3. **Databricks Job IDs**
   - Go to: Databricks → Workflows → Select your job
   - **Job ID** is in the URL: `.../jobs/1054308664529427`
   - Note the IDs of jobs you want to trigger from Airflow

### Store in AWS Secrets Manager (Optional, Recommended)

Instead of hardcoding Databricks token in `.env`, use Secrets Manager:

```bash
# Create secret
aws secretsmanager create-secret \
  --name databricks/airflow-token \
  --description "Databricks token for Airflow" \
  --secret-string "dapi123456789abcdef..." \
  --region us-east-1

# Update IAM role to allow access
cat > secretsmanager-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:*:secret:databricks/*"
    }
  ]
}
EOF

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-policy \
  --policy-name AirflowSecretsManagerAccess \
  --policy-document file://secretsmanager-policy.json

aws iam attach-role-policy \
  --role-name AirflowEC2Role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AirflowSecretsManagerAccess
```

---

## 8. Summary Checklist

Before deploying Airflow, verify you have:

### AWS Resources Created:
- [ ] **ECR Repository**: `my-dags`
- [ ] **S3 Bucket**: `data-platform-adeola` (or your name)
- [ ] **IAM Role**: `AirflowEC2Role` with ECR + S3 access
- [ ] **Security Group**: `airflow-sg` with ports 22, 8080 open
- [ ] **EC2 Instance**: Running with IAM role attached

### Values to Note Down:
- [ ] **ECR Registry URL**: `_____.dkr.ecr.us-east-1.amazonaws.com`
- [ ] **S3 Bucket Name**: `_____`
- [ ] **EC2 Public IP**: `_____`
- [ ] **EC2 SSH Key**: `_____.pem`

### GitHub Secrets Configured:
- [ ] `AWS_ACCESS_KEY_ID`
- [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] `ECR_REGISTRY`

### Databricks Information:
- [ ] **Workspace URL**: `https://_____.cloud.databricks.com`
- [ ] **Access Token**: `dapi_____`
- [ ] **Job IDs**: List of jobs to trigger

---

## 9. Quick Setup Script

Here's a script that sets up everything at once:

```bash
#!/bin/bash

# Configuration
export AWS_REGION=us-east-1
export ECR_REPO=my-dags
export S3_BUCKET=data-platform-$(whoami)  # Use your name
export KEY_PAIR_NAME=airflow-key

echo "=========================================="
echo "AWS Infrastructure Setup for Airflow"
echo "=========================================="
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo "ECR Registry: ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 1. Create ECR repository
echo ""
echo "Creating ECR repository..."
aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION || echo "ECR repo may already exist"

# 2. Create S3 bucket
echo ""
echo "Creating S3 bucket..."
aws s3 mb s3://$S3_BUCKET --region $AWS_REGION || echo "S3 bucket may already exist"

# 3. Create IAM role (simplified - you may want to customize)
echo ""
echo "Creating IAM role..."
# (Use the detailed commands from section 3 above)

# 4. Create security group
echo ""
echo "Creating security group..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
SG_ID=$(aws ec2 create-security-group \
  --group-name airflow-sg \
  --description "Airflow security group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text) || SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=airflow-sg" --query 'SecurityGroups[0].GroupId' --output text)

MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr ${MY_IP}/32 || true
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr ${MY_IP}/32 || true

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "ECR Registry: ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "S3 Bucket: $S3_BUCKET"
echo "Security Group: $SG_ID"
echo ""
echo "Next steps:"
echo "1. Launch EC2 instance using security group: $SG_ID"
echo "2. Attach IAM role: AirflowEC2Role"
echo "3. Add GitHub secrets (see section 6)"
echo "4. SSH into EC2 and run setup_ec2_instance.sh"
echo ""
```

---

## 10. Next Steps

Once you have all resources created:

1. **SSH into your EC2 instance:**
   ```bash
   ssh -i your-key.pem ec2-user@your-ec2-public-ip
   ```

2. **Run the setup script:**
   ```bash
   curl -O https://raw.githubusercontent.com/TechDeo/databricks-airflow3.0-template/ec2-docker-compose/setup_ec2_instance.sh
   chmod +x setup_ec2_instance.sh
   ./setup_ec2_instance.sh
   ```

3. **Clone the repository and deploy:**
   ```bash
   git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
   cd airflow
   cp .env.example .env
   # Edit .env with your values
   vim .env
   ./manage_docker_compose.sh start
   ```

4. **Access Airflow UI:**
   - Open browser: `http://your-ec2-ip:8080`
   - Login: `admin` / `admin` (or your configured password)

5. **Configure Databricks connection in Airflow UI**

---

## Troubleshooting

### Can't push to ECR
```bash
# Check ECR permissions
aws ecr describe-repositories --repository-names my-dags

# Re-authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
```

### EC2 can't pull from ECR
```bash
# Check IAM role is attached
aws ec2 describe-instances --instance-ids i-xxxxx --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Test from EC2
aws ecr describe-repositories
```

### Can't access Airflow UI
```bash
# Check security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Update your IP if it changed
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id sg-xxxxx --protocol tcp --port 8080 --cidr ${MY_IP}/32
```

---

That's it! You should now have all AWS resources set up and ready to deploy Airflow. 🚀
