# Create a Kubernetes secret for GCS credentials
kubectl create secret generic vault-gcs-credentials --from-file=credentials.json=vault-backups-11e33c76a79f.json --namespace vault