#!/bin/bash
set -e

# Count pods not in Running state for a given namespace
count_not_running() {
    local namespace=$1
    kubectl get pods -n "$namespace" --no-headers 2>/dev/null | \
        grep -v "Running" | \
        wc -l | \
        tr -d ' '
}

# Check if a namespace exists
check_namespace() {
    local namespace=$1
    kubectl get namespace "$namespace" &> /dev/null && \
        echo "✓ Namespace: $namespace" || \
        echo "✗ Namespace: $namespace"
}

# Check pods in a namespace
check_pods() {
    local namespace=$1
    local not_running=$(count_not_running "$namespace")

    if [ "$not_running" -eq 0 ]; then
        echo "✓ All $namespace pods running"
    else
        echo "✗ $not_running $namespace pods not running"
        kubectl get pods -n "$namespace" | grep -v "Running" || true
    fi
}

# Check if a service exists
check_service() {
    local service=$1
    local namespace=$2
    local display_name=$3
    kubectl get svc "$service" -n "$namespace" &> /dev/null && \
        echo "✓ $display_name" || \
        echo "✗ $display_name"
}

echo "kind-stack-observability Health Check"
echo "========================================"

# Check cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "✗ Cluster not reachable"
    exit 1
fi
echo "✓ Cluster reachable"

# Check namespaces
check_namespace observability
check_namespace demo

# Check all pods are running
echo ""
echo "Pods:"
check_pods observability
check_pods demo

# Check key services exist
echo ""
echo "Services:"
check_service prometheus-server observability "Prometheus"
check_service grafana observability "Grafana"
check_service opensearch-cluster-master observability "OpenSearch"
check_service podinfo-frontend demo "podinfo-frontend"
check_service podinfo-backend demo "podinfo-backend"

# Final health check result
echo ""
echo "========================================"
NOT_RUNNING_OBS=$(count_not_running observability)
NOT_RUNNING_DEMO=$(count_not_running demo)

if [ "$NOT_RUNNING_OBS" -eq 0 ] && [ "$NOT_RUNNING_DEMO" -eq 0 ]; then
    echo "✓ Health check passed"
    exit 0
else
    echo "✗ Health check failed"
    exit 1
fi
