.DEFAULT_GOAL := create

pre:
	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
	@kubectl wait --namespace metallb-system \
		--for=condition=ready pod \
		--selector=app=metallb \
		--timeout=300s
	@kubectl apply -f manifests/

helm:
	@helmfile apply

create:
	@kind create cluster --config maxxi-insights-lab/Cluster/config.yaml

up: create pre helm

destroy:
	@kind delete clusters kind

set-namespace:
	@kubectl config set-context --current --namespace $(n)

# Uso: make set-namespace n=NAMESPACE

k8s/access_db:
	kubectl port-forward svc/postgres -n database 5433:5432

k8s/access_storage:
	kubectl port-forward svc/minio -n storage 9000:9000 9090:9090

k8s/access_trino:
	kubectl port-forward svc/trino -n query-engine 8080:8080

k8s/rollout:
	kubectl apply -f k8s/query-engine/

	kubectl rollout restart deployment trino-coordinator -n query-engine
	kubectl rollout restart deployment trino-worker -n query-engine

k8s/rollout_catalogue:
	kubectl apply -f k8s/catalogue/

	kubectl rollout restart deployment hive-metastore -n catalogue

