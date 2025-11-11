#!/bin/bash

# Automated Airflow Deployment Script
# This script deploys Airflow to your EC2 instance

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration - Update these values or pass as environment variables
EC2_IP="${EC2_IP:-3.80.41.115}"
SSH_KEY="${SSH_KEY:-/Users/adeola.oladeji/Code/Learning/databricks-airflow3.0-template/airflow-key.pem}"
ECR_REGISTRY="${ECR_REGISTRY:-223340170015.dkr.ecr.us-east-1.amazonaws.com}"
ECR_REPO="${ECR_REPO:-my-dags}"
IMAGE_TAG="${IMAGE_TAG:-20251111114508}"
AWS_REGION="${AWS_REGION:-us-east-1}"
S3_BUCKET="${S3_BUCKET:-data-platform-adeola}"
DATABRICKS_HOST="${DATABRICKS_HOST:-}"
DATABRICKS_TOKEN="${DATABRICKS_TOKEN:-}"

# Check Databricks variables (warn if not set)
if [ -z "$DATABRICKS_HOST" ] || [ -z "$DATABRICKS_TOKEN" ]; then
    echo -e "${YELLOW}WARNING: DATABRICKS_HOST and DATABRICKS_TOKEN not set${NC}"
    echo -e "${YELLOW}You can configure Databricks connection later in Airflow UI${NC}"
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Airflow Deployment to EC2${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Test SSH connection
echo -e "${YELLOW}Step 1: Testing SSH connection...${NC}"
ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@$EC2_IP "echo 'SSH connection successful'" || {
    echo -e "${RED}Failed to connect to EC2. Check your key permissions:${NC}"
    echo "chmod 400 $SSH_KEY"
    exit 1
}

# Step 2: Setup EC2 instance (install Docker, Docker Compose)
echo -e "${YELLOW}Step 2: Setting up EC2 instance...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << 'ENDSSH'
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker and Docker Compose..."
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER

        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        # Install Git if not present
        sudo yum install -y git

        echo "Docker and Docker Compose installed!"
    else
        echo "Docker already installed, skipping..."
    fi
ENDSSH

# Step 3: Clone or update repository
echo -e "${YELLOW}Step 3: Cloning/updating repository...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << ENDSSH
    if [ -d "airflow" ]; then
        echo "Repository exists, pulling latest changes..."
        cd airflow
        git pull origin ec2-docker-compose
    else
        echo "Cloning repository..."
        git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git airflow
        cd airflow
    fi
ENDSSH

# Step 4: Create .env file
echo -e "${YELLOW}Step 4: Creating .env configuration...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << ENVEOF
    cd airflow
    cat > .env << 'EOF'
# Airflow Configuration
AIRFLOW_UID=50000
AIRFLOW_PROJ_DIR=.

# Airflow Admin User
_AIRFLOW_WWW_USER_USERNAME=admin
_AIRFLOW_WWW_USER_PASSWORD=admin

# AWS ECR Configuration
ECR_REGISTRY=${ECR_REGISTRY}
ECR_REPO=${ECR_REPO}
IMAGE_TAG=${IMAGE_TAG}
AWS_DEFAULT_REGION=${AWS_REGION}

# S3 Bucket
S3_BUCKET=${S3_BUCKET}

# Databricks Connection
AIRFLOW_CONN_DATABRICKS_CONN=databricks://token:${DATABRICKS_TOKEN}@${DATABRICKS_HOST}?port=443&ssl=true

# PostgreSQL Configuration
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow
POSTGRES_DB=airflow
EOF
    echo ".env file created!"
ENVEOF

# Step 5: Login to ECR
echo -e "${YELLOW}Step 5: Logging into AWS ECR...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << ENDSSH
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
ENDSSH

# Step 6: Pull Docker image
echo -e "${YELLOW}Step 6: Pulling Docker image from ECR...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << ENDSSH
    cd airflow
    docker pull ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}
ENDSSH

# Step 7: Create required directories
echo -e "${YELLOW}Step 7: Creating directories...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << 'ENDSSH'
    cd airflow
    mkdir -p logs plugins config
    sudo chown -R 50000:0 logs plugins config dags
ENDSSH

# Step 8: Start Airflow services
echo -e "${YELLOW}Step 8: Starting Airflow services...${NC}"
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << 'ENDSSH'
    cd airflow

    # Stop any existing containers
    docker-compose down 2>/dev/null || true

    # Start services
    docker-compose up -d

    echo "Waiting for services to start..."
    sleep 20

    # Check status
    docker-compose ps
ENDSSH

# Step 9: Verify deployment
echo -e "${YELLOW}Step 9: Verifying deployment...${NC}"
sleep 5
ssh -i "$SSH_KEY" ec2-user@$EC2_IP << 'ENDSSH'
    cd airflow

    echo ""
    echo "Container Status:"
    docker-compose ps

    echo ""
    echo "Recent Logs:"
    docker-compose logs --tail=20
ENDSSH

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Airflow UI: ${GREEN}http://${EC2_IP}:8080${NC}"
echo -e "Username:   ${GREEN}admin${NC}"
echo -e "Password:   ${GREEN}admin${NC}"
echo ""
echo -e "Databricks connection is already configured!"
echo ""
echo -e "To check logs:"
echo -e "  ssh -i $SSH_KEY ec2-user@$EC2_IP"
echo -e "  cd airflow && docker-compose logs -f"
echo ""
echo -e "To restart services:"
echo -e "  ssh -i $SSH_KEY ec2-user@$EC2_IP"
echo -e "  cd airflow && ./manage_docker_compose.sh restart"
echo ""
