# Airflow on EC2 with Docker Compose

This guide explains how to deploy Apache Airflow 3.0 on an EC2 instance using Docker Compose to trigger Databricks jobs.

## Architecture Overview

```
GitHub → CI/CD → AWS ECR → EC2 Instance
                             ↓
                   Docker Compose (Airflow)
                             ↓
                   Databricks Jobs (via API)
```

### Components:
- **EC2 Instance**: Hosts Docker Compose services
- **Docker Compose**: Orchestrates Airflow services (webserver, scheduler, triggerer, PostgreSQL)
- **AWS ECR**: Container registry for Airflow images
- **PostgreSQL**: Airflow metadata database
- **Databricks**: Data transformation platform (jobs triggered by Airflow)

## Prerequisites

### AWS Resources:
1. **EC2 Instance**
   - Recommended: t3.medium or larger (2 vCPU, 4GB RAM minimum)
   - OS: Amazon Linux 2023 or Amazon Linux 2
   - Storage: 20GB+ EBS volume
   - Security Group: Allow inbound on port 8080 (Airflow UI) and 22 (SSH)

2. **IAM Role** (recommended) or AWS credentials with permissions for:
   - ECR: Pull images
   - S3: Read/write to data buckets (if using S3 in DAGs)
   - Secrets Manager: (optional) Store Databricks tokens

3. **AWS ECR Repository**
   - Repository name: `my-dags`
   - Region: `us-east-1` (or your preferred region)

4. **Databricks Workspace**
   - Databricks workspace URL
   - Databricks personal access token
   - Job IDs for workflows to trigger

### GitHub Secrets (for CI/CD):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (if using temporary credentials)
- `ECR_REGISTRY` (e.g., `223340170015.dkr.ecr.us-east-1.amazonaws.com`)

## Quick Start

### Step 1: Launch and Setup EC2 Instance

1. **Launch EC2 instance:**
   ```bash
   # Use AWS Console or CLI to launch Amazon Linux 2023 instance
   # Attach IAM role with ECR, S3 permissions
   # Configure security group to allow port 8080, 22
   ```

2. **SSH into EC2:**
   ```bash
   ssh -i your-key.pem ec2-user@your-ec2-public-ip
   ```

3. **Run setup script:**
   ```bash
   # Download and run setup script
   curl -O https://raw.githubusercontent.com/TechDeo/databricks-airflow3.0-template/ec2-docker-compose/setup_ec2_instance.sh
   chmod +x setup_ec2_instance.sh
   ./setup_ec2_instance.sh

   # Log out and back in for docker group changes
   exit
   ssh -i your-key.pem ec2-user@your-ec2-public-ip
   ```

### Step 2: Clone Repository and Configure

1. **Clone repository:**
   ```bash
   cd ~
   git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
   cd airflow
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   vim .env  # or nano .env
   ```

   Update these key variables in `.env`:
   ```bash
   # ECR Configuration
   ECR_REGISTRY=223340170015.dkr.ecr.us-east-1.amazonaws.com
   ECR_REPO=my-dags
   IMAGE_TAG=20251030140337  # Use latest tag from ECR

   # AWS Region
   AWS_DEFAULT_REGION=us-east-1

   # Airflow Admin (change password!)
   _AIRFLOW_WWW_USER_USERNAME=admin
   _AIRFLOW_WWW_USER_PASSWORD=your-secure-password

   # Databricks (configure in Airflow UI or set here)
   # AIRFLOW_CONN_DATABRICKS_CONN=databricks://token:your_token@your_workspace.cloud.databricks.com?port=443&ssl=true
   ```

3. **Login to AWS ECR:**
   ```bash
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin $ECR_REGISTRY
   ```

### Step 3: Start Airflow

```bash
# Make management script executable
chmod +x manage_docker_compose.sh

# Start all services
./manage_docker_compose.sh start
```

Wait 30-60 seconds for services to initialize, then access:
- **Airflow UI**: `http://your-ec2-public-ip:8080`
- **Username**: `admin`
- **Password**: (as set in `.env`)

### Step 4: Configure Databricks Connection

1. **Via Airflow UI** (recommended):
   - Navigate to Admin → Connections
   - Add new connection:
     - Connection Id: `databricks_conn`
     - Connection Type: `Databricks`
     - Host: `your-workspace.cloud.databricks.com`
     - Login: `token`
     - Password: `your-databricks-token`
     - Port: `443`
     - Extra: `{"use_ssl": true}`

2. **Via Environment Variable** (alternative):
   Update `.env` and restart services:
   ```bash
   AIRFLOW_CONN_DATABRICKS_CONN=databricks://token:dapi123...@your-workspace.cloud.databricks.com?port=443&ssl=true
   ```

## Management Commands

The `manage_docker_compose.sh` script provides easy management:

```bash
# Start all services
./manage_docker_compose.sh start

# Stop all services
./manage_docker_compose.sh stop

# Restart services
./manage_docker_compose.sh restart

# Check status
./manage_docker_compose.sh status

# View logs (all services)
./manage_docker_compose.sh logs

# View logs (specific service)
./manage_docker_compose.sh logs scheduler
./manage_docker_compose.sh logs webserver

# Open shell in webserver container
./manage_docker_compose.sh shell

# Build image locally (if not using ECR)
./manage_docker_compose.sh build

# Pull latest image from ECR
./manage_docker_compose.sh pull

# Update code and restart
./manage_docker_compose.sh update

# Clean all data (WARNING: deletes everything)
./manage_docker_compose.sh clean
```

## Deployment and Updates

### Automatic Deployment (CI/CD)

When you push code to the `ec2-docker-compose` branch:

1. GitHub Actions builds a new Docker image
2. Image is pushed to AWS ECR with date-based tag (YYYYMMDD)
3. On EC2, pull the latest image and restart:
   ```bash
   # Update IMAGE_TAG in .env to latest tag
   vim .env  # Change IMAGE_TAG=YYYYMMDD

   # Pull and restart
   ./manage_docker_compose.sh pull
   docker-compose up -d
   ```

### Manual Deployment

Update DAGs without rebuilding image (development):
```bash
# Edit DAGs locally
vim dags/your_dag.py

# Restart scheduler to pick up changes
docker-compose restart airflow-scheduler
```

Update everything (production):
```bash
cd ~/airflow
git pull origin ec2-docker-compose
./manage_docker_compose.sh update
```

## DAG Configuration

The project includes three DAGs:

### 1. `example_dag.py`
Simple hello/goodbye workflow for testing.

### 2. `produce_data_assets.py`
Downloads StackExchange data and uploads to S3.
- **Schedule**: Daily
- **Purpose**: Create data assets for downstream jobs
- **Outputs**: S3 files that trigger Databricks workflows

### 3. `trigger_databricks_workflow_dag.py`
Triggers Databricks jobs based on data assets or schedule.

**Configuration:**
1. Update Job IDs in the DAG file:
   ```python
   job_id = 1054308664529427  # Your Databricks job ID
   ```

2. Configure trigger type:
   - **Asset-based** (data-driven):
     ```python
     schedule=(posts_asset & users_asset)
     ```
   - **Time-based** (cron):
     ```python
     schedule="0 9 * * 0"  # Every Sunday at 9 AM
     ```

## Monitoring and Troubleshooting

### Check Service Health

```bash
# Check all containers
docker-compose ps

# Check logs
docker-compose logs -f

# Check specific service
docker-compose logs -f scheduler
docker-compose logs -f webserver
docker-compose logs -f triggerer
```

### Common Issues

**1. Services won't start:**
```bash
# Check Docker daemon
sudo systemctl status docker

# Check disk space
df -h

# Check memory
free -h
```

**2. Can't pull from ECR:**
```bash
# Re-authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Verify IAM permissions
aws ecr describe-repositories
```

**3. Databricks connection fails:**
```bash
# Test from container
docker-compose exec airflow-webserver bash
python -c "from airflow.providers.databricks.hooks.databricks import DatabricksHook; hook = DatabricksHook('databricks_conn'); print(hook.test_connection())"
```

**4. DAGs not appearing:**
```bash
# Check DAG folder permissions
ls -la dags/

# Restart scheduler
docker-compose restart airflow-scheduler

# Check scheduler logs
docker-compose logs scheduler | grep -i error
```

### Resource Monitoring

```bash
# Container resource usage
docker stats

# System resources
htop

# Disk usage
du -sh logs/
docker system df
```

## Security Best Practices

### Production Recommendations:

1. **Change default passwords:**
   - Update `_AIRFLOW_WWW_USER_PASSWORD` in `.env`
   - Use strong, unique passwords

2. **Use AWS Secrets Manager:**
   - Store Databricks tokens in Secrets Manager
   - Reference in Airflow connections
   - Never commit secrets to Git

3. **Restrict Security Group:**
   - Port 8080: Only allow your IP or VPN
   - Port 22: Only allow bastion host or your IP
   - Consider using AWS Systems Manager Session Manager instead of SSH

4. **Use IAM Roles:**
   - Attach IAM role to EC2 instance
   - Don't use long-term AWS credentials in `.env`

5. **Enable HTTPS:**
   - Use Application Load Balancer with SSL certificate
   - Or configure nginx reverse proxy with Let's Encrypt

6. **Regular Updates:**
   - Keep Docker images updated
   - Patch EC2 instance regularly
   - Update Airflow providers

7. **Backup Data:**
   - Regular PostgreSQL backups
   - Consider RDS for managed database
   - Backup DAG files to S3

## Cost Optimization

### EC2 Instance:
- Use Spot Instances for non-critical environments (up to 90% savings)
- Schedule instance start/stop for dev environments
- Right-size instance based on actual usage

### Storage:
- Use gp3 EBS volumes (cheaper than gp2)
- Clean up old logs regularly:
  ```bash
  find logs/ -type f -mtime +30 -delete
  ```

### ECR:
- Use lifecycle policies to delete old images
- Keep only last 10 images or images from last 30 days

## Scaling Considerations

For higher workloads:

1. **Vertical Scaling:**
   - Increase EC2 instance size
   - Add more memory/CPU

2. **Horizontal Scaling:**
   - Switch to CeleryExecutor
   - Add Redis to docker-compose
   - Add worker services

3. **Managed Services:**
   - Use Amazon MWAA (Managed Workflows for Apache Airflow)
   - Use RDS for PostgreSQL instead of containerized database
   - Use ElastiCache for Redis

## Migration from Kubernetes

Key differences from the original Kubernetes setup:

| Feature | Kubernetes (Original) | Docker Compose (EC2) |
|---------|----------------------|----------------------|
| Executor | KubernetesExecutor | LocalExecutor |
| Database | Embedded PostgreSQL | Containerized PostgreSQL |
| Scaling | Auto-scaling pods | Manual instance scaling |
| High Availability | Multi-node | Single node |
| Complexity | High | Low |
| Cost | Higher (cluster overhead) | Lower (single instance) |
| Maintenance | More complex | Simpler |

## Support and Resources

- **Airflow Documentation**: https://airflow.apache.org/docs/apache-airflow/stable/
- **Databricks Provider**: https://airflow.apache.org/docs/apache-airflow-providers-databricks/
- **Docker Compose**: https://docs.docker.com/compose/
- **Project Repository**: https://github.com/TechDeo/databricks-airflow3.0-template

## Next Steps

1. **Configure Databricks Jobs**: Update DAGs with your job IDs
2. **Set up Monitoring**: Consider CloudWatch, Datadog, or Prometheus
3. **Configure Alerts**: Email or Slack notifications for DAG failures
4. **Enable Git Sync**: Auto-sync DAGs from GitHub (optional)
5. **Set up Backups**: Automate PostgreSQL and configuration backups
6. **Implement CI/CD**: Automate deployment on code changes

## License

This project is provided as-is for educational purposes. Not recommended for production use without additional hardening and testing.
