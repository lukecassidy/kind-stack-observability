CLUSTER_NAME ?= kind-stack-observability

.PHONY: kind-up kind-down deploy destroy status \
        pf-prometheus pf-grafana pf-opensearch pf-dashboards pf-podinfo pf-all pf-stop

kind-up:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml

kind-down:
	kind delete cluster --name $(CLUSTER_NAME) || true

deploy:
	kubectl apply -f manifests/namespaces.yaml
	helmfile sync

destroy:
	helmfile destroy

status:
	kubectl get pods -A

pf-prometheus:
	kubectl port-forward svc/prometheus-server -n observability 9090:80

pf-grafana:
	kubectl port-forward svc/grafana -n observability 3000:80

pf-opensearch:
	kubectl port-forward svc/opensearch-cluster-master -n observability 9200:9200

pf-dashboards:
	kubectl port-forward svc/opensearch-dashboards -n observability 5601:5601

pf-podinfo:
	kubectl port-forward svc/podinfo-frontend -n demo 8080:9898

pf-all:
	kubectl port-forward svc/prometheus-server -n observability 9090:80 &
	kubectl port-forward svc/grafana -n observability 3000:80 &
	kubectl port-forward svc/opensearch-cluster-master -n observability 9200:9200 &
	kubectl port-forward svc/opensearch-dashboards -n observability 5601:5601 &
	kubectl port-forward svc/podinfo-frontend -n demo 8080:9898 &
	kubectl port-forward svc/podinfo-backend -n demo 8081:9898 &
	wait

pf-stop:
	@echo "Stopping all port-forwards..."
	@pkill -f "kubectl port-forward" || true
