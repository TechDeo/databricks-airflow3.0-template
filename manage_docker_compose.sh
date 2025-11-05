#!/bin/bash

# Management script for Airflow Docker Compose deployment
# Provides easy commands to start, stop, restart, and monitor Airflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Function to display usage
usage() {
    echo -e "${BLUE}======================================"
    echo "Airflow Docker Compose Manager"
    echo "======================================${NC}"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|logs|shell|build|clean|update}"
    echo ""
    echo "Commands:"
    echo "  start    - Start all Airflow services"
    echo "  stop     - Stop all Airflow services"
    echo "  restart  - Restart all Airflow services"
    echo "  status   - Show status of all services"
    echo "  logs     - Follow logs (optional: specify service name)"
    echo "  shell    - Open shell in webserver container"
    echo "  build    - Build Docker image locally"
    echo "  pull     - Pull latest image from ECR"
    echo "  clean    - Remove all containers and volumes (WARNING: deletes data)"
    echo "  update   - Pull latest code and restart services"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs scheduler"
    echo "  $0 status"
    echo ""
}

# Function to start services
start_services() {
    echo -e "${GREEN}Starting Airflow services...${NC}"

    # Check if .env exists
    if [ ! -f .env ]; then
        echo -e "${YELLOW}Warning: .env file not found. Creating from .env.example...${NC}"
        cp .env.example .env
        echo -e "${YELLOW}Please edit .env file and run this command again.${NC}"
        exit 1
    fi

    # Login to ECR if using ECR
    if [ ! -z "$ECR_REGISTRY" ]; then
        echo "Logging in to AWS ECR..."
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION:-us-east-1} | \
            docker login --username AWS --password-stdin $ECR_REGISTRY
    fi

    docker-compose up -d

    echo -e "\n${GREEN}Services started successfully!${NC}"
    echo ""
    echo "Airflow UI will be available at: http://localhost:8080"
    echo "Default credentials: admin / admin"
    echo ""
    echo "Run '$0 logs' to view logs"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping Airflow services...${NC}"
    docker-compose down
    echo -e "${GREEN}Services stopped.${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${YELLOW}Restarting Airflow services...${NC}"
    docker-compose restart
    echo -e "${GREEN}Services restarted.${NC}"
}

# Function to show status
show_status() {
    echo -e "${BLUE}======================================"
    echo "Airflow Services Status"
    echo "======================================${NC}"
    echo ""
    docker-compose ps
    echo ""

    # Check if services are healthy
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Services are running${NC}"

        # Get public IP if on EC2
        if [ -f /sys/hypervisor/uuid ] && [ `head -c 3 /sys/hypervisor/uuid` == ec2 ]; then
            PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "Unable to fetch")
            echo -e "\nAirflow UI: http://${PUBLIC_IP}:8080"
        else
            echo -e "\nAirflow UI: http://localhost:8080"
        fi
    else
        echo -e "${RED}✗ Services are not running${NC}"
    fi
}

# Function to show logs
show_logs() {
    SERVICE=${1:-}
    if [ -z "$SERVICE" ]; then
        echo -e "${BLUE}Following logs for all services (Ctrl+C to exit)...${NC}"
        docker-compose logs -f
    else
        echo -e "${BLUE}Following logs for $SERVICE (Ctrl+C to exit)...${NC}"
        docker-compose logs -f $SERVICE
    fi
}

# Function to open shell
open_shell() {
    echo -e "${GREEN}Opening shell in airflow-webserver container...${NC}"
    docker-compose exec airflow-webserver bash
}

# Function to build image locally
build_image() {
    echo -e "${GREEN}Building Docker image locally...${NC}"
    IMAGE_TAG=${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}

    docker build -f cicd/Dockerfile -t my-dags:${IMAGE_TAG} .
    docker tag my-dags:${IMAGE_TAG} my-dags:latest

    # Update .env file with new tag
    if [ -f .env ]; then
        sed -i.bak "s/IMAGE_TAG=.*/IMAGE_TAG=${IMAGE_TAG}/" .env
        echo -e "${GREEN}Updated IMAGE_TAG in .env to ${IMAGE_TAG}${NC}"
    fi

    echo -e "${GREEN}Build complete!${NC}"
    echo "Image: my-dags:${IMAGE_TAG}"
}

# Function to pull image from ECR
pull_image() {
    if [ -z "$ECR_REGISTRY" ]; then
        echo -e "${RED}ECR_REGISTRY not set in .env file${NC}"
        exit 1
    fi

    echo -e "${GREEN}Pulling latest image from ECR...${NC}"

    # Login to ECR
    aws ecr get-login-password --region ${AWS_DEFAULT_REGION:-us-east-1} | \
        docker login --username AWS --password-stdin $ECR_REGISTRY

    # Pull image
    docker pull ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}

    echo -e "${GREEN}Pull complete!${NC}"
}

# Function to clean everything
clean_all() {
    echo -e "${RED}======================================"
    echo "WARNING: This will remove all containers,"
    echo "volumes, and delete all Airflow data!"
    echo "======================================${NC}"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" = "yes" ]; then
        echo -e "${YELLOW}Cleaning up...${NC}"
        docker-compose down -v
        rm -rf logs/* plugins/* config/*
        echo -e "${GREEN}Cleanup complete.${NC}"
    else
        echo -e "${GREEN}Cleanup cancelled.${NC}"
    fi
}

# Function to update
update_services() {
    echo -e "${GREEN}Updating Airflow deployment...${NC}"

    # Pull latest code
    echo "Pulling latest code from git..."
    git pull origin ec2-docker-compose

    # Pull or build image
    if [ ! -z "$ECR_REGISTRY" ]; then
        pull_image
    else
        build_image
    fi

    # Restart services
    echo "Restarting services with new code..."
    docker-compose up -d

    echo -e "${GREEN}Update complete!${NC}"
}

# Main script logic
case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs $2
        ;;
    shell)
        open_shell
        ;;
    build)
        build_image
        ;;
    pull)
        pull_image
        ;;
    clean)
        clean_all
        ;;
    update)
        update_services
        ;;
    *)
        usage
        exit 1
        ;;
esac
