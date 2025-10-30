#!/bin/bash

# Airflow Management Script for Kind Cluster

case "$1" in
  start)
    echo "🚀 Starting Airflow..."
    echo ""

    # Check if cluster exists
    if kind get clusters | grep -q "^kind$"; then
      echo "✅ Kind cluster exists"

      # Check if airflow namespace exists
      if kubectl get namespace airflow &> /dev/null; then
        echo "✅ Airflow namespace exists"
        echo ""
        echo "📊 Pod Status:"
        kubectl get pods -n airflow
        echo ""
        echo "🌐 Starting port-forward..."
        echo "   Access Airflow at: http://localhost:8080"
        echo "   Username: admin"
        echo "   Password: admin"
        echo ""
        kubectl port-forward svc/airflow-api-server 8080:8080 --namespace airflow
      else
        echo "❌ Airflow not installed"
        echo "   Run: ./install_airflow.sh"
      fi
    else
      echo "❌ Kind cluster doesn't exist"
      echo "   Run: ./install_airflow.sh"
    fi
    ;;

  stop)
    echo "🛑 Stopping port-forward..."
    # Kill any running port-forward processes
    pkill -f "kubectl port-forward svc/airflow-api-server"
    echo "✅ Port-forward stopped"
    echo ""
    echo "💡 Tip: Cluster still running. Use './manage_airflow.sh delete' to remove it completely"
    ;;

  status)
    echo "📊 Airflow Status"
    echo ""

    # Check cluster
    if kind get clusters | grep -q "^kind$"; then
      echo "✅ Kind cluster: Running"
    else
      echo "❌ Kind cluster: Not found"
      exit 1
    fi

    # Check namespace
    if kubectl get namespace airflow &> /dev/null; then
      echo "✅ Airflow namespace: Exists"
      echo ""

      # Pod status
      echo "📦 Pod Status:"
      kubectl get pods -n airflow
      echo ""

      # Service status
      echo "🌐 Services:"
      kubectl get svc -n airflow
      echo ""

      # Check port-forward
      if lsof -i :8080 &> /dev/null; then
        echo "✅ Port-forward: Active on http://localhost:8080"
      else
        echo "⚠️  Port-forward: Not running"
        echo "   Run: ./manage_airflow.sh start"
      fi
    else
      echo "❌ Airflow namespace: Not found"
      echo "   Run: ./install_airflow.sh"
    fi
    ;;

  restart)
    echo "🔄 Restarting Airflow pods..."
    kubectl rollout restart deployment -n airflow
    kubectl rollout restart statefulset -n airflow
    echo "✅ Restart initiated"
    echo ""
    echo "⏳ Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l release=airflow -n airflow --timeout=300s
    echo "✅ All pods ready"
    ;;

  delete)
    echo "⚠️  WARNING: This will delete the entire Kind cluster"
    echo "   All data will be lost!"
    echo ""
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
      echo "🗑️  Deleting Kind cluster..."
      kind delete cluster --name kind
      echo "✅ Cluster deleted"
      echo ""
      echo "💡 To reinstall: ./install_airflow.sh"
    else
      echo "❌ Cancelled"
    fi
    ;;

  logs)
    if [ -z "$2" ]; then
      echo "Usage: ./manage_airflow.sh logs [component]"
      echo ""
      echo "Components:"
      echo "  scheduler       - Airflow scheduler logs"
      echo "  dag-processor   - DAG processor logs"
      echo "  git-sync        - GitSync logs"
      echo "  api-server      - API server logs"
      echo "  triggerer       - Triggerer logs"
      exit 1
    fi

    case "$2" in
      scheduler)
        POD=$(kubectl get pod -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')
        kubectl logs -f $POD -n airflow -c scheduler
        ;;
      dag-processor)
        POD=$(kubectl get pod -n airflow -l component=dag-processor -o jsonpath='{.items[0].metadata.name}')
        kubectl logs -f $POD -n airflow -c dag-processor
        ;;
      git-sync)
        POD=$(kubectl get pod -n airflow -l component=dag-processor -o jsonpath='{.items[0].metadata.name}')
        kubectl logs -f $POD -n airflow -c git-sync
        ;;
      api-server)
        POD=$(kubectl get pod -n airflow -l component=api-server -o jsonpath='{.items[0].metadata.name}')
        kubectl logs -f $POD -n airflow
        ;;
      triggerer)
        kubectl logs -f airflow-triggerer-0 -n airflow -c triggerer
        ;;
      *)
        echo "Unknown component: $2"
        exit 1
        ;;
    esac
    ;;

  *)
    echo "Airflow Management Script"
    echo ""
    echo "Usage: ./manage_airflow.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start      - Start port-forward to access Airflow UI"
    echo "  stop       - Stop port-forward (cluster keeps running)"
    echo "  status     - Show cluster and pod status"
    echo "  restart    - Restart all Airflow pods"
    echo "  delete     - Delete entire Kind cluster"
    echo "  logs       - View logs (scheduler, dag-processor, git-sync, api-server, triggerer)"
    echo ""
    echo "Examples:"
    echo "  ./manage_airflow.sh start"
    echo "  ./manage_airflow.sh status"
    echo "  ./manage_airflow.sh logs git-sync"
    echo "  ./manage_airflow.sh delete"
    ;;
esac
