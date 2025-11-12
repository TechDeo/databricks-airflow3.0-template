#!/bin/bash
set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REGISTRY=${ECR_REGISTRY:-223340170015.dkr.ecr.us-east-1.amazonaws.com}
ECR_REPO=${ECR_REPO:-my-dags}
IMAGE_TAG=${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}

echo "========================================="
echo "Building and Pushing Airflow Custom Image"
echo "========================================="
echo "Registry: ${ECR_REGISTRY}"
echo "Repository: ${ECR_REPO}"
echo "Tag: ${IMAGE_TAG}"
echo ""

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build the Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPO}:${IMAGE_TAG} -t ${ECR_REPO}:latest .

# Tag for ECR
echo "Tagging image for ECR..."
docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}
docker tag ${ECR_REPO}:latest ${ECR_REGISTRY}/${ECR_REPO}:latest

# Push to ECR
echo "Pushing image to ECR..."
docker push ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}
docker push ${ECR_REGISTRY}/${ECR_REPO}:latest

echo ""
echo "========================================="
echo "✅ Build and Push Complete!"
echo "========================================="
echo "Image: ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
echo "Latest: ${ECR_REGISTRY}/${ECR_REPO}:latest"
echo ""
echo "To deploy, update your docker-compose.yaml:"
echo "  image: ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
