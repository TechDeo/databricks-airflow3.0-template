# Create or replace a kind cluster
kind delete cluster --name kind
kind create cluster --image kindest/node:v1.34.0

# Add airflow to my Helm repo
helm repo add apache-airflow https://airflow.apache.org
helm repo update
helm show values apache-airflow/airflow > chart/values-example.yaml

# Export values for Airflow docker image
export IMAGE_NAME=my-dags
export IMAGE_TAG=$(date +%Y%m%d)
export NAMESPACE=airflow
export RELEASE_NAME=airflow

# Build the image and load it into kind
docker build --pull --tag $IMAGE_NAME:$IMAGE_TAG -f cicd/Dockerfile .
kind load docker-image $IMAGE_NAME:$IMAGE_TAG

# Pre-load required images for Kind (fixes TLS issues in local environment)
# NOTE: This is only needed for Kind - production clusters pull images automatically
echo "Loading dependent images into Kind cluster..."
docker pull --platform linux/amd64 postgres:16-alpine
docker pull --platform linux/amd64 quay.io/prometheus/statsd-exporter:v0.28.0
docker pull --platform linux/amd64 registry.k8s.io/git-sync/git-sync:v4.3.0

# Use docker save/ctr import method for reliable loading
docker save postgres:16-alpine | docker exec -i kind-control-plane ctr -n k8s.io images import -
docker save quay.io/prometheus/statsd-exporter:v0.28.0 | docker exec -i kind-control-plane ctr -n k8s.io images import -
docker save registry.k8s.io/git-sync/git-sync:v4.3.0 | docker exec -i kind-control-plane ctr -n k8s.io images import -

# Create a namespace
kubectl create namespace $NAMESPACE

# Apply kubernetes secrets
kubectl apply -f k8s/secrets/git-secrets.yaml

# Install Airflow using Helm
helm install $RELEASE_NAME apache-airflow/airflow \
    --namespace $NAMESPACE -f chart/values-override.yaml \
    --set-string images.airflow.tag="$IMAGE_TAG" \
    --debug

# Port forward the API server
kubectl port-forward svc/$RELEASE_NAME-api-server 8080:8080 --namespace $NAMESPACE