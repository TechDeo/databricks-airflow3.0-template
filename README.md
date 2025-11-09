# Databricks and Airflow 3.0 on EC2

Supporting notes for Youtube tutorial: https://youtu.be/92X54U6gm0Y

Implements a data platform using Databricks for transformation and Airflow 3.0 for orchestration, deployed on EC2 with Docker Compose.

## Features

- **Data-aware orchestration** using Airflow 3.0 Data Assets
- **Declarative transformation** with Databricks notebooks
- **Incremental upsert loading** using Delta Lake
- **Docker Compose deployment** on EC2 for simplicity
- **Data Quality checks** using DQX library
- **CI/CD pipeline** with GitHub Actions
- **AWS ECR** for container registry
- **Terraform** for infrastructure provisioning

## Why Docker Compose on EC2?

- **Simpler to deploy and manage** - No Kubernetes complexity
- **Lower resource requirements** - Single EC2 instance
- **Perfect for Databricks workloads** - Airflow triggers jobs, doesn't run heavy processing
- **Cost-effective** - ~$30-60/month vs cluster overhead

---

## Prerequisites

### AWS Resources
- AWS Account with access to EC2, ECR, S3
- AWS CLI configured (or use Terraform)
- Databricks workspace with access token
- GitHub repository for CI/CD

### Local Tools
- Terraform (if provisioning infrastructure)
- Git
- SSH client

---

## Quick Start (3 Options)

### Option 1: Terraform (Automated)

```bash
# Clone repository
git clone https://github.com/TechDeo/databricks-airflow3.0-template.git
cd databricks-airflow3.0-template/terraform

# Configure variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Update your values

# Provision infrastructure
terraform init
terraform plan
terraform apply

# Note the outputs (EC2 IP, ECR registry, etc.)
```

### Option 2: Manual AWS Setup

1. **Create ECR Repository**:
   ```bash
   aws ecr create-repository --repository-name my-dags --region us-east-1
   ```

2. **Create S3 Bucket**:
   ```bash
   aws s3 mb s3://data-platform-yourname --region us-east-1
   ```

3. **Create IAM Role** with policies:
   - `AmazonEC2ContainerRegistryReadOnly`
   - `AmazonS3FullAccess` (or scoped to your bucket)

4. **Launch EC2 Instance** (t3.medium or larger):
   - AMI: Amazon Linux 2023
   - Attach IAM role from step 3
   - Security Group: Allow ports 22 (SSH) and 8080 (Airflow)
   - 20GB+ storage

### Option 3: Use Existing EC2

If you already have an EC2 instance, skip to the deployment steps below.

---

## Deployment

### Step 1: Configure GitHub Secrets (for CI/CD)

Go to GitHub repo → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (if using temporary credentials)
- `ECR_REGISTRY` (format: `123456789012.dkr.ecr.us-east-1.amazonaws.com`)

### Step 2: Setup EC2 Instance

SSH into your EC2 instance:
```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
```

Run setup script:
```bash
curl -O https://raw.githubusercontent.com/TechDeo/databricks-airflow3.0-template/ec2-docker-compose/setup_ec2_instance.sh
chmod +x setup_ec2_instance.sh
./setup_ec2_instance.sh

# Log out and back in for docker group changes
exit
ssh -i your-key.pem ec2-user@your-ec2-ip
```

### Step 3: Clone and Configure

```bash
# Clone repository
git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
cd airflow

# Configure environment
cp .env.example .env
vim .env
```

Update these key values in `.env`:
```bash
# ECR Configuration
ECR_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com
ECR_REPO=my-dags
IMAGE_TAG=20251030140337  # Use latest tag from ECR

# AWS
AWS_DEFAULT_REGION=us-east-1

# Airflow Admin (CHANGE PASSWORD!)
_AIRFLOW_WWW_USER_PASSWORD=your-secure-password

# S3
S3_BUCKET=data-platform-yourname

# Databricks (optional - can configure in UI instead)
# AIRFLOW_CONN_DATABRICKS_CONN=databricks://token:dapi123@workspace.cloud.databricks.com?port=443&ssl=true
```

### Step 4: Login to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

### Step 5: Start Airflow

```bash
chmod +x manage_docker_compose.sh
./manage_docker_compose.sh start
```

Wait 30-60 seconds, then access:
- **Airflow UI**: `http://your-ec2-ip:8080`
- **Username**: `admin`
- **Password**: (as set in `.env`)

### Step 6: Configure Databricks Connection

**In Airflow UI**: Admin → Connections → Add Connection

- Connection Id: `databricks_conn`
- Connection Type: `Databricks`
- Host: `your-workspace.cloud.databricks.com`
- Login: `token`
- Password: `your-databricks-token`
- Port: `443`
- Extra: `{"use_ssl": true}`

---

## Management Commands

Use the `manage_docker_compose.sh` script for easy management:

```bash
# Start services
./manage_docker_compose.sh start

# Stop services
./manage_docker_compose.sh stop

# Check status
./manage_docker_compose.sh status

# View logs
./manage_docker_compose.sh logs
./manage_docker_compose.sh logs scheduler  # Specific service

# Open shell
./manage_docker_compose.sh shell

# Pull latest image from ECR
./manage_docker_compose.sh pull

# Update code and restart
./manage_docker_compose.sh update

# Clean all data (WARNING: deletes everything)
./manage_docker_compose.sh clean
```

---

## DAG Configuration

### Included DAGs

1. **example_dag.py** - Simple test workflow
2. **produce_data_assets.py** - Downloads data to S3
3. **trigger_databricks_workflow_dag.py** - Triggers Databricks jobs

### Update with Your Databricks Job IDs

Edit the DAG file:
```bash
vim dags/trigger_databricks_workflow_dag.py
```

Update job IDs:
```python
job_id = 1054308664529427  # Replace with your Databricks job ID
```

Restart scheduler:
```bash
docker-compose restart airflow-scheduler
```

---

## CI/CD Pipeline

When you push to `ec2-docker-compose` branch:
1. GitHub Actions builds Docker image
2. Image is tagged with date (YYYYMMDD format)
3. Image is pushed to ECR

To deploy updates:
```bash
# Update IMAGE_TAG in .env with new date tag
vim .env

# Pull and restart
./manage_docker_compose.sh pull
docker-compose up -d
```

---

## Troubleshooting

### Services won't start
```bash
# Check Docker
sudo systemctl status docker

# Check resources
df -h
free -h

# View logs
docker-compose logs -f
```

### Can't pull from ECR
```bash
# Re-authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Verify IAM permissions
aws ecr describe-repositories
```

### Can't connect to Databricks
```bash
# Test connection from container
docker-compose exec airflow-webserver bash
python -c "from airflow.providers.databricks.hooks.databricks import DatabricksHook; hook = DatabricksHook('databricks_conn'); print(hook.test_connection())"
```

### DAGs not appearing
```bash
# Check DAG folder
ls -la dags/

# Restart scheduler
docker-compose restart airflow-scheduler

# Check logs
docker-compose logs scheduler | grep -i error
```

---

## Production Recommendations

### Security
- Change default admin password
- Use AWS Secrets Manager for credentials
- Restrict security group to specific IPs
- Enable HTTPS via ALB or nginx
- Use VPN or bastion host for SSH

### Reliability
- Use RDS for PostgreSQL (instead of containerized DB)
- Enable automated backups
- Set up CloudWatch monitoring
- Configure SNS alerts for failures
- Enable remote logging to S3

### Cost Optimization
- Use Spot Instances for dev/test (90% savings)
- Right-size EC2 based on usage
- Set up ECR lifecycle policies
- Clean up old logs regularly
- Schedule instance start/stop for dev environments

---

## Architecture

```
GitHub (code) → CI/CD → AWS ECR (images)
                           ↓
                     EC2 Instance
                           ↓
               Docker Compose (Airflow)
                 ↓           ↓
            PostgreSQL   Databricks Jobs
                           ↓
                      S3 Data Assets
```

### Components
- **EC2**: Hosts Docker Compose
- **Docker Compose**: Orchestrates containers (webserver, scheduler, triggerer, dag-processor, PostgreSQL)
- **ECR**: Container image registry
- **Databricks**: Data transformation platform
- **S3**: Data storage

---

## File Structure

```
.
├── dags/                      # Airflow DAG files
├── terraform/                 # Infrastructure as code
├── cicd/Dockerfile           # Airflow image
├── docker-compose.yaml       # Container orchestration
├── manage_docker_compose.sh  # Management script
├── setup_ec2_instance.sh     # One-time EC2 setup
├── .env.example              # Environment template
└── README.md                 # This file
```

---

## Support

- **Airflow Docs**: https://airflow.apache.org/docs/
- **Databricks Provider**: https://airflow.apache.org/docs/apache-airflow-providers-databricks/
- **Docker Compose**: https://docs.docker.com/compose/
- **GitHub Issues**: Open an issue for bugs or questions

---

## License

This is educational code for demonstration purposes. While suitable for development and small production workloads, consider additional hardening for large-scale production use.
