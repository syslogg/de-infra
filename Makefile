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

passwd:
	@echo "JENKINS:"
	@kubectl get secret -n jenkins jenkins -ojson | jq -r '.data."jenkins-admin-password"' | base64 -d
	@echo ""
	@echo "GITEA:"
	@echo "r8sA8CPHD9!bt6d | jenkins: fv#4ChTvoBhtRc"
	@echo "SONARQUBE:"
	@echo "krE^NiQvTc@75G"
	@echo "ARGOCD:"
	@kubectl get secret -n argocd argocd-initial-admin-secret -ojson | jq -r '.data.password' | base64 -d

k8s/access_db:
	kubectl port-forward svc/postgres -n database 5433:5432

k8s/access_storage:
	kubectl port-forward svc/minio -n storage 9000:9000

k8s/rollout:
	kubectl apply -f k8s/catalogue/hive-metastore-deployment.yml
	kubectl apply -f k8s/catalogue/hive-configmap.yml
	kubectl apply -f k8s/catalogue/hive-db-secret.yml

	kubectl rollout restart deployment hive-metastore -n catalogue
