#!/bin/bash
set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'
PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARNING="${ORANGE}✗${NC}"

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
        echo -e "  ${PASS} Namespace: $namespace" || \
        echo -e "  ${FAIL} Namespace: $namespace"
}

# Check pods in a namespace
check_pods() {
    local namespace=$1
    local not_running=$(count_not_running "$namespace")

    if [ "$not_running" -eq 0 ]; then
        echo -e "  ${PASS} Pods: $namespace (all running)"
    else
        echo -e "  ${FAIL} Pods: $namespace ($not_running not running)"
        kubectl get pods -n "$namespace" | grep -v "Running" || true
    fi
}

# Check if a service exists
check_service() {
    local service=$1
    local namespace=$2
    local display_name=$3
    kubectl get svc "$service" -n "$namespace" &> /dev/null && \
        echo -e "  ${PASS} Service: $display_name" || \
        echo -e "  ${WARNING} Service: $display_name (not found)"
}

# Main execution
echo "Health Check Report"

# Check cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "  ${FAIL} Cluster: not reachable"
    exit 1
fi
echo -e "  ${PASS} Cluster: reachable"

# Check namespaces
check_namespace observability
check_namespace demo

# Check all pods are running
check_pods observability
check_pods demo

# Check key services exist
check_service prometheus-server observability "Prometheus"
check_service grafana observability "Grafana"
check_service opensearch-cluster-master observability "OpenSearch"
check_service podinfo-frontend demo "podinfo-frontend"
check_service podinfo-backend demo "podinfo-backend"

# Final health check result
NOT_RUNNING_OBS=$(count_not_running observability)
NOT_RUNNING_DEMO=$(count_not_running demo)

if [ "$NOT_RUNNING_OBS" -eq 0 ] && [ "$NOT_RUNNING_DEMO" -eq 0 ]; then
    echo -e "${GREEN}Health Check Passed${NC}"
    exit 0
else
    echo -e "${RED}Health Check Failed${NC}"
    exit 1
fi
