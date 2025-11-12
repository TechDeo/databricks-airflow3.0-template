# How to Check Airflow Logs and Errors

## Log Volume Location

All Airflow logs are stored in the `logs/` directory on your EC2 instance:
```bash
/home/ec2-user/airflow/logs/
```

This directory is mounted as a volume in docker-compose.yaml:
```yaml
volumes:
  - ./logs:/opt/airflow/logs
```

## Log Directory Structure

```
logs/
├── dag_id=example_dag/          # DAG-specific logs
│   └── run_id=manual__2025-11-12T20:06:39.../
│       ├── task_id=hello_world/
│       │   └── attempt=1.log    # Task execution logs
│       └── task_id=goodbye_world/
│           └── attempt=1.log
├── dag_processor/               # DAG processor logs
│   └── 2025-11-12/
│       └── dags-folder/
│           └── example_dag.py.log
├── dag_processor_manager/       # DAG processor manager logs
└── scheduler/                   # Scheduler logs
```

## SSH Commands to Check Logs

### 1. Check Service Status
```bash
ssh -i your-key.pem ec2-user@98.93.151.214
cd /home/ec2-user/airflow
docker-compose ps
```

### 2. Check Container Logs (Most Important)
```bash
# Check scheduler logs
docker logs airflow-airflow-scheduler-1 --tail 100

# Check api-server logs
docker logs airflow-airflow-api-server-1 --tail 100

# Check triggerer logs
docker logs airflow-airflow-triggerer-1 --tail 100

# Check dag-processor logs
docker logs airflow-airflow-dag-processor-1 --tail 100

# Follow logs in real-time
docker logs -f airflow-airflow-scheduler-1
```

### 3. Check Task Logs on Disk
```bash
# List recent task logs
find logs/dag_id=example_dag -name "*.log" -mmin -30

# Read a specific task log
cat logs/dag_id=example_dag/run_id=manual__2025-11-12T.../task_id=hello_world/attempt=1.log

# Search for errors in logs
grep -r "ERROR" logs/ | tail -20
grep -r "FAILED" logs/ | tail -20
grep -r "No host supplied" logs/
```

### 4. Check DAG Processor Logs
```bash
# Check if DAGs are parsing correctly
cat logs/dag_processor/$(date +%Y-%m-%d)/dags-folder/example_dag.py.log
```

## AWS SSM Commands (No SSH Required)

If you can't SSH, use AWS Systems Manager:

### Check Service Status
```bash
aws ssm send-command \
  --instance-ids i-052e51f231386f32e \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["cd /home/ec2-user/airflow && docker-compose ps"]}' \
  --output text --query 'Command.CommandId'

# Get results
aws ssm get-command-invocation \
  --command-id <COMMAND_ID_FROM_ABOVE> \
  --instance-id i-052e51f231386f32e \
  --query 'StandardOutputContent' \
  --output text
```

### Check Container Logs
```bash
aws ssm send-command \
  --instance-ids i-052e51f231386f32e \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["docker logs airflow-airflow-scheduler-1 --tail 50"]}' \
  --output text --query 'Command.CommandId'
```

### Check for Specific Errors
```bash
aws ssm send-command \
  --instance-ids i-052e51f231386f32e \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["docker logs airflow-airflow-scheduler-1 2>&1 | grep -i \"no host supplied\""]}' \
  --output text --query 'Command.CommandId'
```

## Common Issues and Solutions

### 1. "No host supplied" Error (FIXED)
**Solution:** Added hostname configuration to triggerer service
```yaml
airflow-triggerer:
  hostname: airflow-triggerer
  environment:
    AIRFLOW__TRIGGERER__DEFAULT_HOSTNAME: airflow-triggerer
```

### 2. Task Execution Failures
**Check:** Look at task logs in `logs/dag_id=*/.../*.log`
**Common causes:**
- Missing Python dependencies
- Database connection issues
- Incorrect DAG code

### 3. Services Not Healthy
**Check:** Run `docker-compose ps` and look for unhealthy services
**Solution:** Check container logs with `docker logs <container-name>`

### 4. DAGs Not Appearing in UI
**Check:** DAG processor logs
```bash
docker logs airflow-airflow-dag-processor-1 --tail 50
```

## Restart Services

### Restart All Services
```bash
cd /home/ec2-user/airflow
docker-compose down
docker-compose up -d
```

### Restart Single Service
```bash
docker-compose restart airflow-scheduler
docker-compose restart airflow-api-server
```

### View Logs During Restart
```bash
docker-compose down
docker-compose up  # Without -d to see logs in terminal
```

## Log Retention

Airflow automatically rotates logs. To clean old logs:
```bash
# Delete logs older than 30 days
find logs/ -type f -name "*.log" -mtime +30 -delete

# Check logs disk usage
du -sh logs/
```

## Access Logs from Airflow UI

1. Go to http://98.93.151.214/
2. Login with username: `admin`, password: `admin`
3. Click on any DAG
4. Click on a task instance
5. Click "Log" button to view task logs in browser

## Current Status (After Fix)

✅ All services are healthy
✅ "No host supplied" error is FIXED
✅ FAB auth manager configured (stable password)
✅ All providers installed (databricks, amazon, fab)
✅ ECR custom image: `223340170015.dkr.ecr.us-east-1.amazonaws.com/my-dags:20251112195142`

## Quick Health Check Command

```bash
ssh ec2-user@98.93.151.214 'cd airflow && docker-compose ps && echo && docker logs airflow-airflow-scheduler-1 --tail 10'
```
