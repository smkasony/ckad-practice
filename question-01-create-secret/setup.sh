#!/bin/bash
set -euo pipefail

# Wait for the cluster to be available
cluster_ok=false
for i in {1..60}; do
  if kubectl get nodes >/dev/null 2>&1; then
    cluster_ok=true
    break
  fi
  sleep 2
done

if [[ "$cluster_ok" != "true" ]]; then
  echo "Kubernetes cluster not reachable (expected in Killercoda)." >&2
  echo "If running locally, ensure kubectl is configured and a cluster is running." >&2
  exit 1
fi

# Wait for at least one Ready node (best-effort)
for i in {1..60}; do
  if kubectl get nodes --no-headers 2>/dev/null | grep -q ' Ready '; then
    break
  fi
  sleep 2
done

# Reset scenario state to make this idempotent
kubectl delete secret db-credentials -n default --ignore-not-found
kubectl delete deploy api-server -n default --ignore-not-found

# Create the starting Deployment with hardcoded env vars
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
        - name: api
          image: nginx:1.25
          env:
            - name: DB_USER
              value: admin
            - name: DB_PASS
              value: "Secret123!"
YAML

kubectl rollout status deploy/api-server -n default --timeout=120s
