# Quick Setup Checklist

Use this checklist to track your setup progress. See [AWS_SETUP_GUIDE.md](AWS_SETUP_GUIDE.md) for detailed instructions.

## Phase 1: AWS Resources

### ECR (Container Registry)
- [ ] Created ECR repository named `my-dags`
- [ ] Noted ECR registry URL: `____________.dkr.ecr.us-east-1.amazonaws.com`
- [ ] Configured lifecycle policy (optional)

### S3 (Data Storage)
- [ ] Created S3 bucket: `data-platform-____________`
- [ ] Noted bucket name: `____________`

### IAM Role (EC2 Permissions)
- [ ] Created IAM role: `AirflowEC2Role`
- [ ] Attached policy: `AmazonEC2ContainerRegistryReadOnly`
- [ ] Attached policy: `AmazonS3FullAccess` (or custom S3 policy)
- [ ] Created instance profile: `AirflowEC2InstanceProfile`
- [ ] Added role to instance profile

### Security Group (Network Access)
- [ ] Created security group: `airflow-sg`
- [ ] Added inbound rule: SSH (port 22) from your IP
- [ ] Added inbound rule: HTTP (port 8080) from your IP
- [ ] Noted security group ID: `sg-____________`

### EC2 Instance (Server)
- [ ] Launched EC2 instance (t3.medium or larger)
- [ ] Selected AMI: Amazon Linux 2023
- [ ] Attached IAM instance profile: `AirflowEC2InstanceProfile`
- [ ] Attached security group: `airflow-sg`
- [ ] Created/selected SSH key pair: `____________`
- [ ] Instance is running
- [ ] Noted public IP address: `____________`

## Phase 2: GitHub Configuration

### GitHub Secrets (for CI/CD)
Go to: GitHub repo → Settings → Secrets and variables → Actions

- [ ] Added secret: `AWS_ACCESS_KEY_ID` = `____________`
- [ ] Added secret: `AWS_SECRET_ACCESS_KEY` = `____________`
- [ ] Added secret: `AWS_SESSION_TOKEN` (if using temp credentials)
- [ ] Added secret: `ECR_REGISTRY` = `____________.dkr.ecr.us-east-1.amazonaws.com`

### Test CI/CD Pipeline
- [ ] Pushed code to `ec2-docker-compose` branch
- [ ] GitHub Actions workflow ran successfully
- [ ] Docker image built and pushed to ECR
- [ ] Noted latest image tag: `____________`

## Phase 3: Databricks Configuration

### Databricks Access
- [ ] Have Databricks workspace URL: `https://____________.cloud.databricks.com`
- [ ] Created personal access token
- [ ] Noted token (securely): `dapi____________`
- [ ] Identified job IDs to trigger: `____________`

### Optional: AWS Secrets Manager
- [ ] Created secret in Secrets Manager: `databricks/airflow-token`
- [ ] Updated IAM role with Secrets Manager access

## Phase 4: EC2 Setup

### Connect to EC2
```bash
ssh -i ____________.pem ec2-user@____________
```

- [ ] Successfully connected to EC2 instance

### Run Setup Script
```bash
curl -O https://raw.githubusercontent.com/TechDeo/databricks-airflow3.0-template/ec2-docker-compose/setup_ec2_instance.sh
chmod +x setup_ec2_instance.sh
./setup_ec2_instance.sh
```

- [ ] Setup script completed successfully
- [ ] Logged out and back in (for docker group)

### Clone Repository
```bash
git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
cd airflow
```

- [ ] Repository cloned successfully

### Configure Environment
```bash
cp .env.example .env
vim .env
```

Update these values in `.env`:
- [ ] `ECR_REGISTRY=____________.dkr.ecr.us-east-1.amazonaws.com`
- [ ] `ECR_REPO=my-dags`
- [ ] `IMAGE_TAG=____________` (latest from ECR)
- [ ] `AWS_DEFAULT_REGION=us-east-1`
- [ ] `_AIRFLOW_WWW_USER_PASSWORD=____________` (change from default!)
- [ ] `S3_BUCKET=____________`

Optional Databricks config in `.env`:
- [ ] `AIRFLOW_CONN_DATABRICKS_CONN=databricks://token:____________@____________.cloud.databricks.com?port=443&ssl=true`

### Login to ECR
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

- [ ] Successfully logged in to ECR

## Phase 5: Deploy Airflow

### Start Services
```bash
chmod +x manage_docker_compose.sh
./manage_docker_compose.sh start
```

- [ ] All containers started successfully
- [ ] No errors in logs: `docker-compose logs`

### Access Airflow UI
- [ ] Opened browser: `http://____________:8080`
- [ ] Logged in with: `admin` / `____________`
- [ ] Dashboard loaded successfully

### Configure Databricks Connection
In Airflow UI: Admin → Connections → Add Connection

- [ ] Connection Id: `databricks_conn`
- [ ] Connection Type: `Databricks`
- [ ] Host: `____________.cloud.databricks.com`
- [ ] Login: `token`
- [ ] Password: `____________` (your Databricks token)
- [ ] Extra: `{"use_ssl": true}`
- [ ] Tested connection successfully

## Phase 6: Verify DAGs

### Check DAGs are Loaded
- [ ] `example_dag` appears in UI
- [ ] `produce_data_assets` appears in UI
- [ ] `trigger_databricks_workflow_dag` appears in UI

### Update DAG with Your Job IDs
```bash
vim dags/trigger_databricks_workflow_dag.py
# Update job_id = YOUR_JOB_ID
docker-compose restart airflow-scheduler
```

- [ ] Updated job IDs in DAG
- [ ] Restarted scheduler

### Test DAGs
- [ ] Manually triggered `example_dag`
- [ ] DAG ran successfully
- [ ] Manually triggered `trigger_databricks_workflow_dag`
- [ ] Databricks job was triggered successfully

## Phase 7: Production Readiness (Optional)

### Security Enhancements
- [ ] Changed default Airflow admin password
- [ ] Restricted security group to corporate IPs only
- [ ] Set up HTTPS (ALB or nginx with Let's Encrypt)
- [ ] Moved secrets to AWS Secrets Manager
- [ ] Enabled VPN or bastion host access

### Reliability Improvements
- [ ] Migrated to RDS for PostgreSQL
- [ ] Set up automated backups
- [ ] Configured CloudWatch monitoring
- [ ] Set up SNS alerts for failures
- [ ] Enabled remote logging to S3

### Cost Optimization
- [ ] Right-sized EC2 instance based on usage
- [ ] Set up ECR lifecycle policies
- [ ] Configured log rotation
- [ ] Set up instance start/stop schedule (for dev)

---

## Quick Reference Values

Fill in your specific values here for easy reference:

```
AWS Account ID: ____________
AWS Region: us-east-1

ECR Registry: ____________.dkr.ecr.us-east-1.amazonaws.com
ECR Repository: my-dags
Latest Image Tag: ____________

S3 Bucket: ____________

EC2 Instance ID: i-____________
EC2 Public IP: ____________
EC2 Key Pair: ____________.pem

Security Group: sg-____________
IAM Role: AirflowEC2Role

Databricks Workspace: ____________.cloud.databricks.com
Databricks Job IDs: ____________

GitHub Repo: https://github.com/TechDeo/databricks-airflow3.0-template
Branch: ec2-docker-compose
```

---

## Useful Commands

```bash
# SSH to EC2
ssh -i ____________.pem ec2-user@____________

# Check Airflow status
./manage_docker_compose.sh status

# View logs
./manage_docker_compose.sh logs

# Restart Airflow
./manage_docker_compose.sh restart

# Update deployment
./manage_docker_compose.sh update

# ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ____________.dkr.ecr.us-east-1.amazonaws.com

# View latest ECR image
aws ecr describe-images --repository-name my-dags --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' --output text
```

---

## Troubleshooting

If something doesn't work, check:
1. Security group allows your current IP
2. IAM role is attached to EC2 instance
3. Docker containers are running: `docker-compose ps`
4. Check logs: `docker-compose logs -f`
5. Verify `.env` file has correct values

See [AWS_SETUP_GUIDE.md](AWS_SETUP_GUIDE.md) for detailed troubleshooting steps.
