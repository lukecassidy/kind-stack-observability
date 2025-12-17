#!/bin/bash

# Integration test script for kind-stack-observability
# Verifies that all components are functional and can communicate

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

echo "========================================"
echo "Integration Test Suite"
echo "========================================"
echo ""

# Helper function to print test results
pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
}

info() {
    echo -e "ℹ $1"
}

# Test 1: Verify all pods are running
echo "Test 1: Checking pod health..."
if kubectl get pods -n observability | grep -v NAME | awk '{print $3}' | grep -v Running > /dev/null; then
    fail "Not all pods in observability namespace are running"
else
    pass "All observability pods are running"
fi

if kubectl get pods -n demo | grep -v NAME | awk '{print $3}' | grep -v Running > /dev/null; then
    fail "Not all pods in demo namespace are running"
else
    pass "All demo pods are running"
fi
echo ""

# Test 2: Verify Prometheus is scraping targets
echo "Test 2: Checking Prometheus metrics collection..."
PROM_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=prometheus -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n observability "$PROM_POD" -c prometheus-server -- wget -q -O- http://localhost:9090/api/v1/targets | grep -q '"up"'; then
    pass "Prometheus is scraping targets"
else
    fail "Prometheus is not scraping targets correctly"
fi
echo ""

# Test 3: Verify AlertManager is running
echo "Test 3: Checking AlertManager..."
AM_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=alertmanager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$AM_POD" ]; then
    if kubectl exec -n observability "$AM_POD" -- wget -q -O- http://localhost:9093/-/healthy | grep -q "OK"; then
        pass "AlertManager is healthy"
    else
        fail "AlertManager is not healthy"
    fi
else
    fail "AlertManager pod not found"
fi
echo ""

# Test 4: Verify Grafana datasource
echo "Test 4: Checking Grafana datasource configuration..."
GRAFANA_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n observability "$GRAFANA_POD" -- wget -q -O- --header="Authorization: Basic YWRtaW46YWRtaW4=" http://localhost:3000/api/datasources | grep -q "Prometheus"; then
    pass "Grafana has Prometheus datasource configured"
else
    fail "Grafana datasource not configured"
fi
echo ""

# Test 5: Verify OpenSearch cluster health
echo "Test 5: Checking OpenSearch cluster health..."
OS_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=opensearch -o jsonpath='{.items[0].metadata.name}')
CLUSTER_HEALTH=$(kubectl exec -n observability "$OS_POD" -- curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$CLUSTER_HEALTH" = "green" ] || [ "$CLUSTER_HEALTH" = "yellow" ]; then
    pass "OpenSearch cluster is $CLUSTER_HEALTH"
else
    fail "OpenSearch cluster health is $CLUSTER_HEALTH"
fi
echo ""

# Test 6: Verify Fluent Bit is forwarding logs
echo "Test 6: Checking Fluent Bit log forwarding..."
FB_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=fluent-bit -o jsonpath='{.items[0].metadata.name}')
if kubectl logs -n observability "$FB_POD" --tail=50 | grep -q "output:opensearch"; then
    pass "Fluent Bit is configured to forward to OpenSearch"
else
    warn "Could not verify Fluent Bit output configuration"
fi
echo ""

# Test 7: Verify logs are being indexed in OpenSearch
echo "Test 7: Checking log ingestion..."
sleep 5  # Give time for logs to be indexed
DOC_COUNT=$(kubectl exec -n observability "$OS_POD" -- curl -s http://localhost:9200/_cat/count/kubernetes-logs* | awk '{print $3}')
if [ -n "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
    pass "Logs are being indexed ($DOC_COUNT documents)"
else
    warn "No logs found in OpenSearch yet (may need more time)"
fi
echo ""

# Test 8: Verify Jaeger is receiving traces
echo "Test 8: Checking Jaeger collector..."
JAEGER_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n observability "$JAEGER_POD" -- wget -q -O- http://localhost:16686/ | grep -q "html"; then
    pass "Jaeger query UI is available"
else
    fail "Jaeger query UI is not responding"
fi
echo ""

# Test 9: Test podinfo frontend-to-backend communication
echo "Test 9: Testing podinfo frontend-to-backend communication..."
PODINFO_FRONTEND=$(kubectl get pod -n demo -l app.kubernetes.io/name=podinfo-frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_URL="http://podinfo-backend:9898/echo"
RESPONSE=$(kubectl exec -n demo "$PODINFO_FRONTEND" -- wget -q -O- --post-data='{"test":"integration"}' "$BACKEND_URL" 2>/dev/null || echo "")
if echo "$RESPONSE" | grep -q "integration"; then
    pass "Frontend can communicate with backend"
else
    fail "Frontend-to-backend communication failed"
fi
echo ""

# Test 10: Verify metrics are being collected from podinfo
echo "Test 10: Checking application metrics..."
METRICS=$(kubectl exec -n observability "$PROM_POD" -c prometheus-server -- wget -q -O- 'http://localhost:9090/api/v1/query?query=up{app="podinfo"}' | grep -o '"value":\[[^]]*\]')
if echo "$METRICS" | grep -q "1"; then
    pass "Application metrics are being collected"
else
    fail "Application metrics not found"
fi
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED test(s) failed${NC}"
    exit 1
fi
