#!/bin/bash
set -e

# This script runs automatically when EC2 instance is launched
# It sets up Docker, Docker Compose, and AWS CLI

echo "======================================"
echo "Starting EC2 instance setup..."
echo "======================================"

# Update system
echo "Updating system packages..."
yum update -y

# Install Docker
echo "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
echo "Adding ec2-user to docker group..."
usermod -aG docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI v2..."
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install Git
echo "Installing Git..."
yum install -y git

# Install useful tools
echo "Installing additional tools..."
yum install -y htop vim curl wget

# Create directory for Airflow
echo "Creating directory structure..."
mkdir -p /home/ec2-user/airflow
chown -R ec2-user:ec2-user /home/ec2-user/airflow

# Verify installations
echo "Verifying installations..."
docker --version
docker-compose --version
aws --version
git --version

echo ""
echo "======================================"
echo "EC2 Setup Complete!"
echo "======================================"
echo ""
echo "Installed:"
echo "  - Docker $(docker --version | awk '{print $3}')"
echo "  - Docker Compose $(docker-compose --version | awk '{print $4}')"
echo "  - AWS CLI $(aws --version | awk '{print $1}' | cut -d/ -f2)"
echo "  - Git $(git --version | awk '{print $3}')"
echo ""
echo "Next steps:"
echo "  1. SSH into this instance as ec2-user"
echo "  2. Clone the repository:"
echo "     git clone -b ec2-docker-compose https://github.com/TechDeo/databricks-airflow3.0-template.git ~/airflow"
echo "  3. Configure .env file"
echo "  4. Run: ./manage_docker_compose.sh start"
echo ""
