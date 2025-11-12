# Databricks Airflow 3.0 Template

Production-ready Apache Airflow 3.0.2 deployment on AWS EC2 with Terraform.

## Features

- **Airflow 3.0.2** with api-server architecture
- **Terraform** infrastructure provisioning
- **AWS Secrets Manager** for credentials
- **LocalExecutor** with PostgreSQL
- **Docker Compose** deployment
- **Environment isolation** (dev/staging/prod)

## Quick Start

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform workspace select dev || terraform workspace new dev
terraform apply -var-file=dev.tfvars
```

### 2. Populate Secrets

```bash
aws secretsmanager put-secret-value \
  --secret-id airflow-dev-airflow-admin-password \
  --secret-string "YourPassword123!" \
  --region us-east-1
```

### 3. Deploy Airflow

```bash
# Via SSM (bypasses firewall)
aws ssm send-command \
  --instance-ids YOUR_INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "cd /home/ec2-user",
    "git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow",
    "cd airflow && mkdir -p logs plugins config dags",
    "docker-compose up -d"
  ]'
```

### 4. Access

Open `http://YOUR_EC2_IP` in browser
- Username: `admin`
- Password: (from secrets manager)

## Airflow 3.0 Changes

Airflow 3.0 replaces `webserver` with **`api-server`**:

```yaml
services:
  airflow-api-server:  # NEW in 3.0
    command: api-server  # not webserver

  airflow-scheduler:
    command: scheduler
```

## Project Structure

```
.
├── terraform/          # Infrastructure
│   ├── main.tf        # EC2, IAM, Secrets
│   ├── backend.tf     # S3 remote state
│   └── dev.tfvars     # Environment config
├── dags/              # Airflow DAGs
├── docker-compose.yaml # Airflow 3.0 services
└── .env.example       # Config template
```

## Infrastructure

- **EC2**: t3.medium Amazon Linux 2023
- **Ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8080
- **IAM**: ECR, S3, Secrets Manager access
- **State**: S3 backend with DynamoDB locking

## Troubleshooting

**SSH/Port 8080 blocked?**
Use AWS Systems Manager - works over HTTPS (port 443).

**Reset password:**
```bash
docker exec airflow-api-server airflow users reset-password \
  --username admin --password NewPassword123!
```

**View logs:**
```bash
docker-compose logs -f airflow-api-server
```

## License

MIT
