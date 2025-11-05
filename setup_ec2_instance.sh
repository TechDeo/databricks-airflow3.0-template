#!/bin/bash

# Script to set up an EC2 instance for running Airflow with Docker Compose
# This script should be run on the EC2 instance after first launch

set -e

echo "======================================"
echo "Setting up EC2 instance for Airflow"
echo "======================================"

# Update system packages
echo "Updating system packages..."
sudo yum update -y

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to docker group (so we don't need sudo)
echo "Adding current user to docker group..."
sudo usermod -aG docker $USER

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose installation
echo "Verifying Docker Compose installation..."
docker-compose --version

# Install Git
echo "Installing Git..."
sudo yum install -y git

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "AWS CLI already installed"
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p ~/airflow-deployment/{dags,logs,plugins,config}

# Set proper permissions
echo "Setting permissions..."
sudo chown -R $USER:$USER ~/airflow-deployment

# Configure Docker to start on boot
echo "Configuring Docker to start on boot..."
sudo systemctl enable docker

# Install useful tools
echo "Installing additional tools..."
sudo yum install -y htop vim curl wget

echo ""
echo "======================================"
echo "EC2 Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Log out and log back in for docker group changes to take effect"
echo "   (or run: newgrp docker)"
echo "2. Configure AWS credentials if not using IAM role:"
echo "   aws configure"
echo "3. Clone your repository:"
echo "   cd ~/airflow-deployment"
echo "   git clone https://github.com/TechDeo/databricks-airflow3.0-template.git ."
echo "4. Copy .env.example to .env and configure:"
echo "   cp .env.example .env"
echo "   vim .env"
echo "5. Log in to ECR (if using ECR):"
echo "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-ecr-registry>"
echo "6. Start Airflow:"
echo "   ./manage_docker_compose.sh start"
echo ""
