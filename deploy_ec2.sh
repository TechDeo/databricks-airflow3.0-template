#!/bin/bash

# Script to deploy/update Airflow on EC2 instance
# Can be run locally to push changes to EC2 or on EC2 to pull and restart

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo -e "${GREEN}Loading environment variables from .env${NC}"
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}Warning: .env file not found. Using default values.${NC}"
fi

# Configuration
ECR_REGISTRY=${ECR_REGISTRY:-""}
ECR_REPO=${ECR_REPO:-"my-dags"}
AWS_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
IMAGE_TAG=${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}

echo "======================================"
echo "Deploying Airflow on EC2"
echo "======================================"

# Check if running on EC2 or local
if [ -f /sys/hypervisor/uuid ] && [ `head -c 3 /sys/hypervisor/uuid` == ec2 ]; then
    ON_EC2=true
    echo "Running on EC2 instance"
else
    ON_EC2=false
    echo "Running locally"
fi

# Function to deploy on EC2
deploy_on_ec2() {
    echo -e "${GREEN}Starting deployment on EC2...${NC}"

    # Pull latest code
    echo "Pulling latest code from git..."
    git pull origin ec2-docker-compose

    # Login to ECR if using ECR
    if [ ! -z "$ECR_REGISTRY" ]; then
        echo "Logging in to AWS ECR..."
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

        # Pull latest image
        echo "Pulling latest Docker image from ECR..."
        docker pull ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}
    else
        # Build image locally
        echo "Building Docker image locally..."
        docker build -f cicd/Dockerfile -t my-dags:${IMAGE_TAG} .
    fi

    # Stop existing containers
    echo "Stopping existing containers..."
    docker-compose down || true

    # Start new containers
    echo "Starting new containers..."
    docker-compose up -d

    # Wait for services to be healthy
    echo "Waiting for services to be healthy..."
    sleep 10

    # Check status
    echo -e "\n${GREEN}Checking container status:${NC}"
    docker-compose ps

    echo -e "\n${GREEN}======================================"
    echo "Deployment Complete!"
    echo "======================================${NC}"
    echo ""
    echo "Access Airflow UI at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
    echo "Username: admin"
    echo "Password: admin (or as configured in .env)"
    echo ""
    echo "To view logs: docker-compose logs -f"
    echo "To check status: docker-compose ps"
}

# Function to push from local to EC2
push_to_ec2() {
    read -p "Enter EC2 instance IP or hostname: " EC2_HOST
    read -p "Enter SSH key path: " SSH_KEY
    read -p "Enter EC2 username (default: ec2-user): " EC2_USER
    EC2_USER=${EC2_USER:-ec2-user}

    echo -e "${GREEN}Pushing code to EC2 instance...${NC}"

    # Create tar of current directory (excluding certain files)
    echo "Creating deployment package..."
    tar -czf /tmp/airflow-deploy.tar.gz \
        --exclude='.git' \
        --exclude='tmp' \
        --exclude='logs' \
        --exclude='.env' \
        --exclude='*.pyc' \
        --exclude='__pycache__' \
        .

    # Copy to EC2
    echo "Copying to EC2..."
    scp -i $SSH_KEY /tmp/airflow-deploy.tar.gz ${EC2_USER}@${EC2_HOST}:/tmp/

    # Extract and deploy on EC2
    echo "Deploying on EC2..."
    ssh -i $SSH_KEY ${EC2_USER}@${EC2_HOST} << 'ENDSSH'
        cd ~/airflow-deployment
        tar -xzf /tmp/airflow-deploy.tar.gz
        rm /tmp/airflow-deploy.tar.gz
        ./deploy_ec2.sh
ENDSSH

    # Cleanup local temp file
    rm /tmp/airflow-deploy.tar.gz

    echo -e "\n${GREEN}Push to EC2 complete!${NC}"
}

# Main logic
if [ "$ON_EC2" = true ]; then
    deploy_on_ec2
else
    echo ""
    echo "Choose deployment method:"
    echo "1. Deploy on this EC2 instance (if you're SSH'd into EC2)"
    echo "2. Push from local machine to EC2 instance"
    echo ""
    read -p "Enter choice (1 or 2): " CHOICE

    case $CHOICE in
        1)
            deploy_on_ec2
            ;;
        2)
            push_to_ec2
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
fi
