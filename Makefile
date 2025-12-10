CLUSTER_NAME ?= kind-stack-observability

.PHONY: kind-up kind-down deploy destroy status \
        pf-prometheus pf-grafana pf-kibana pf-all

kind-up:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml

kind-down:
	kind delete cluster --name $(CLUSTER_NAME) || true

deploy:
	helmfile sync

destroy:
	helmfile destroy

status:
	kubectl get pods -A

pf-prometheus:
	kubectl port-forward svc/prometheus-server -n observability 9090:80

pf-grafana:
	kubectl port-forward svc/grafana -n observability 3000:80

pf-kibana:
	kubectl port-forward svc/kibana-kibana -n observability 5601:5601

pf-all:
	kubectl port-forward svc/prometheus-server -n observability 9090:80 &
	kubectl port-forward svc/grafana -n observability 3000:80 &
	kubectl port-forward svc/kibana-kibana -n observability 5601:5601 &
	wait
