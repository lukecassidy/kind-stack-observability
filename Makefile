CLUSTER_NAME ?= kind-stack-observability

.DEFAULT_GOAL := help

.PHONY: help kind-up kind-down deploy destroy status validate health-check integration-test \
        pf-prometheus pf-alertmanager pf-grafana pf-opensearch pf-dashboards pf-jaeger pf-podinfo pf-all pf-stop

help:
	@echo ""
	@echo "kind-stack-observability Help"
	@echo "========================================"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Cluster Management:"
	@echo "  kind-up      Create KIND cluster"
	@echo "  kind-down    Delete KIND cluster"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy            Deploy observability stack and sample apps"
	@echo "  destroy           Remove all Helm releases"
	@echo "  status            Show all pods across namespaces"
	@echo "  validate          Validate Helm charts and YAML syntax"
	@echo "  health-check      Run health checks on deployed apps and services"
	@echo "  integration-test  Run full integration test suite"
	@echo ""
	@echo "Port Forwarding:"
	@echo "  pf-prometheus     Port-forward Prometheus (9090)"
	@echo "  pf-alertmanager   Port-forward AlertManager (9093)"
	@echo "  pf-grafana        Port-forward Grafana (3000)"
	@echo "  pf-opensearch     Port-forward OpenSearch (9200)"
	@echo "  pf-dashboards     Port-forward OpenSearch Dashboards (5601)"
	@echo "  pf-jaeger         Port-forward Jaeger UI (16686)"
	@echo "  pf-podinfo        Port-forward podinfo-frontend (8080)"
	@echo "  pf-all            Port-forward all services"
	@echo "  pf-stop           Stop all port-forwards"
	@echo ""
	@echo "Quick Start:"
	@echo "  make kind-up && make deploy && make health-check && make pf-all"
	@echo ""

kind-up:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml

kind-down:
	kind delete cluster --name $(CLUSTER_NAME) || true

# run validate before deploy (target: dependency)
deploy: validate
	kubectl apply -f manifests/namespaces.yaml
	helmfile sync

destroy:
	helmfile destroy

status:
	kubectl get pods -A

validate:
	@echo "Validating configuration"
	@echo "========================================"
	@helmfile lint
	@bash -n scripts/*.sh
	@echo "✓ Validation passed"

health-check:
	@./scripts/health-check.sh

integration-test:
	@./scripts/integration-test.sh

# port forwarding helpers
pf-prometheus:
	kubectl port-forward svc/prometheus-server -n observability 9090:80

pf-alertmanager:
	kubectl port-forward svc/prometheus-alertmanager -n observability 9093:9093

pf-grafana:
	kubectl port-forward svc/grafana -n observability 3000:80

pf-opensearch:
	kubectl port-forward svc/opensearch-cluster-master -n observability 9200:9200

pf-dashboards:
	kubectl port-forward svc/opensearch-dashboards -n observability 5601:5601

pf-jaeger:
	kubectl port-forward svc/jaeger-query -n observability 16686:16686

pf-podinfo:
	kubectl port-forward svc/podinfo-frontend -n demo 8080:9898

pf-all:
	kubectl port-forward svc/prometheus-server -n observability 9090:80 &
	kubectl port-forward svc/prometheus-alertmanager -n observability 9093:9093 &
	kubectl port-forward svc/grafana -n observability 3000:80 &
	kubectl port-forward svc/opensearch-cluster-master -n observability 9200:9200 &
	kubectl port-forward svc/opensearch-dashboards -n observability 5601:5601 &
	kubectl port-forward svc/jaeger-query -n observability 16686:16686 &
	kubectl port-forward svc/podinfo-frontend -n demo 8080:9898 &
	kubectl port-forward svc/podinfo-backend -n demo 8081:9898 &
	wait

pf-stop:
	@echo "Stopping all port-forwards..."
	@pkill -f "kubectl port-forward" || true
