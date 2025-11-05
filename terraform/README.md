# Terraform for Airflow on EC2

Simple Terraform setup to create all AWS resources needed for Airflow.

## What Gets Created

1. **ECR Repository** - For Docker images
2. **IAM Role** - EC2 permissions for ECR (+ S3 if enabled)
3. **Security Group** - SSH (port 22) + Airflow UI (port 8080)
4. **EC2 Instance** - t3.medium with Docker pre-installed
5. **S3 Bucket** (optional) - Only if you need it

## Quick Start

### 1. Create SSH Key

```bash
aws ec2 create-key-pair \
  --key-name airflow-key \
  --query 'KeyMaterial' \
  --output text > airflow-key.pem

chmod 400 airflow-key.pem
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
my_ip    = "YOUR_IP/32"      # Get it: curl https://checkip.amazonaws.com
key_name = "airflow-key"
```

### 3. Deploy

```bash
terraform init
terraform apply
```

Type `yes` when prompted.

### 4. Get Connection Info

```bash
terraform output ssh_command
terraform output airflow_url
terraform output env_values
```

## S3 Bucket

**Do you need S3?**
- **NO** (default) - If only triggering Databricks jobs
- **YES** - If using `produce_data_assets` DAG

To enable S3, add to `terraform.tfvars`:
```hcl
create_s3_bucket = true
s3_bucket_name   = "data-platform-yourname"
```

## After Deployment

1. **SSH into EC2** (wait 2-3 mins for setup to complete):
```bash
ssh -i airflow-key.pem ec2-user@<IP>
tail -f /var/log/cloud-init-output.log  # Watch setup
```

2. **Clone repo**:
```bash
git clone -b ec2-docker-compose \
  https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
cd airflow
```

3. **Configure .env**:
```bash
cp .env.example .env
# Copy values from: terraform output env_values
vim .env
```

4. **Start Airflow**:
```bash
./manage_docker_compose.sh start
```

5. **Access UI**: http://YOUR_IP:8080

## Commands

```bash
# Preview changes
terraform plan

# Create/update
terraform apply

# Destroy everything
terraform destroy

# Show outputs
terraform output

# Specific output
terraform output instance_public_ip
```

## Costs

- **EC2 t3.medium**: ~$30/month
- **EBS 20GB**: ~$2/month
- **ECR + S3**: Usually free tier
- **Total**: ~$32/month

Stop EC2 when not in use:
```bash
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)
```

## Troubleshooting

**Can't SSH?**
- Check your IP: `curl https://checkip.amazonaws.com`
- Update `my_ip` in terraform.tfvars
- Run `terraform apply` again

**Key pair error?**
- List keys: `aws ec2 describe-key-pairs`
- Create one: See step 1 above

**Wrong region?**
- Change `aws_region` in terraform.tfvars
- Run `terraform apply`

## Files

- `main.tf` - Infrastructure resources
- `variables.tf` - Configuration options
- `outputs.tf` - Important values after deployment
- `user_data.sh` - EC2 setup script
- `terraform.tfvars` - Your configuration (gitignored)
