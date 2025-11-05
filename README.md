# Databricks and Airflow 3.0 Template

Supporting notes for Youtube tutorial: https://youtu.be/92X54U6gm0Y

Implements a bare-bones data platform using Databricks as transformation tool, plus Airflow 3.0 for orchestration, deployed on EC2 using Docker Compose.

## Features

- **Data Aware orchestration** using Airflow 3.0 Data Assets
- **Declarative transformation** on top of Databricks notebooks
- **Incremental upsert loading** using Delta Lake
- **Docker Compose deployment** for simplicity and ease of management
- **Data Quality checks** using DQX library
- **CI/CD** using Github Actions
- **AWS ECR** for container registry
- **EC2 deployment** for production-ready orchestration

## Why Docker Compose on EC2?

This template has been simplified from the original Kubernetes setup to use Docker Compose on EC2 because:

- **Simpler to deploy and manage** - No Kubernetes complexity
- **Lower resource requirements** - Single EC2 instance
- **Perfect for Databricks workloads** - Airflow just triggers Databricks jobs, doesn't run heavy processing
- **Easier troubleshooting** - Direct container access
- **Cost-effective** - Single instance vs cluster overhead

## Quick Start

### Prerequisites

1. **EC2 Instance** (t3.medium or larger recommended)
2. **AWS ECR Repository** for storing Airflow images
3. **Databricks Workspace** with job IDs to trigger
4. **GitHub Secrets** configured for CI/CD:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN` (if using temporary credentials)
   - `ECR_REGISTRY`

### Installation

**Full documentation:** See [README-EC2.md](README-EC2.md) for complete setup instructions.

#### 1. Set up EC2 Instance

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ec2-user@your-ec2-ip

# Download and run setup script
curl -O https://raw.githubusercontent.com/TechDeo/databricks-airflow3.0-template/ec2-docker-compose/setup_ec2_instance.sh
chmod +x setup_ec2_instance.sh
./setup_ec2_instance.sh

# Log out and back in for changes to take effect
exit
```

#### 2. Clone and Configure

```bash
# Clone repository
git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
cd airflow

# Configure environment
cp .env.example .env
vim .env  # Update ECR_REGISTRY, IMAGE_TAG, AWS region, Databricks settings

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

#### 3. Start Airflow

```bash
# Make management script executable
chmod +x manage_docker_compose.sh

# Start all services
./manage_docker_compose.sh start

# Access Airflow UI at http://your-ec2-ip:8080
# Default credentials: admin/admin
```

## Management Commands

```bash
# Start services
./manage_docker_compose.sh start

# Stop services
./manage_docker_compose.sh stop

# Check status
./manage_docker_compose.sh status

# View logs
./manage_docker_compose.sh logs

# View specific service logs
./manage_docker_compose.sh logs scheduler

# Open shell in container
./manage_docker_compose.sh shell

# Update deployment
./manage_docker_compose.sh update
```

## Architecture

![architecture.png](architecture.png)

### Components

- **EC2 Instance**: Hosts all Airflow services
- **Docker Compose**: Orchestrates containers
- **PostgreSQL**: Airflow metadata database
- **Airflow Services**:
  - Webserver (UI on port 8080)
  - Scheduler (triggers DAGs)
  - Triggerer (handles deferred tasks)
- **AWS ECR**: Container image registry
- **Databricks**: Data transformation platform

### Data Flow

```
GitHub → CI/CD → ECR → EC2 Docker Compose → Airflow → Databricks Jobs
                                              ↓
                                        S3 Data Assets
```

## DAGs Included

### 1. `example_dag.py`
Simple hello/goodbye workflow for testing Airflow setup.

### 2. `produce_data_assets.py`
Downloads StackExchange data and uploads to S3 as data assets.
- Schedule: Daily
- Creates assets that trigger downstream workflows

### 3. `trigger_databricks_workflow_dag.py`
Triggers Databricks jobs based on data assets or schedule.
- Supports asset-based triggering (data-driven)
- Supports time-based scheduling (cron)
- Multiple workflow patterns included as examples

## Configuration

### Databricks Connection

Configure in Airflow UI (Admin → Connections):
- **Connection Id**: `databricks_conn`
- **Connection Type**: `Databricks`
- **Host**: `your-workspace.cloud.databricks.com`
- **Login**: `token`
- **Password**: `your-databricks-token`

Or set via environment variable in `.env`:
```bash
AIRFLOW_CONN_DATABRICKS_CONN=databricks://token:your_token@your_workspace.cloud.databricks.com?port=443&ssl=true
```

### Update Job IDs

Edit `dags/trigger_databricks_workflow_dag.py` with your Databricks job IDs:
```python
job_id = 1054308664529427  # Replace with your job ID
```

## CI/CD Pipeline

The GitHub Actions workflow automatically:
1. Builds Docker image on push to `ec2-docker-compose` branch
2. Tags with date (YYYYMMDD format)
3. Pushes to AWS ECR

To deploy updates:
```bash
# Update IMAGE_TAG in .env with latest tag
vim .env

# Pull and restart
./manage_docker_compose.sh pull
docker-compose up -d
```

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

### Can't connect to Databricks
```bash
# Test connection from container
docker-compose exec airflow-webserver bash
airflow connections test databricks_conn
```

### DAGs not appearing
```bash
# Restart scheduler
docker-compose restart airflow-scheduler

# Check logs
docker-compose logs scheduler
```

## Production Recommendations

For production deployment, consider:

1. **Security**:
   - Change default admin password
   - Use AWS Secrets Manager for credentials
   - Restrict security group to specific IPs
   - Enable HTTPS via ALB or nginx

2. **Reliability**:
   - Use RDS for PostgreSQL (instead of containerized)
   - Enable automated backups
   - Set up CloudWatch monitoring
   - Configure SNS alerts for failures

3. **Scaling**:
   - Right-size EC2 instance based on workload
   - Consider CeleryExecutor with workers for high concurrency
   - Use remote logging to S3

4. **Cost Optimization**:
   - Use Spot Instances for dev/test
   - Clean up old logs regularly
   - Set ECR lifecycle policies

## Support

For detailed instructions, see [README-EC2.md](README-EC2.md).

For issues or questions, open an issue on GitHub.

## Disclaimer

This is educational code to demonstrate deploying a data platform with Airflow and Databricks. While suitable for development and small production workloads, consider additional hardening for large-scale production use.

## Original Kubernetes Version

The original Kubernetes/Kind setup is available on the `main` branch. The EC2 Docker Compose version (this branch) provides a simpler alternative for most use cases.
