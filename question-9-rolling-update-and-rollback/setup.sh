#!/bin/bash
set -euo pipefail

# Ensure cluster reachable
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
  exit 1
fi

# Reset scenario state
kubectl delete deploy app-v1 -n default --ignore-not-found

# Create initial deployment
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-v1
  template:
    metadata:
      labels:
        app: app-v1
    spec:
      containers:
        - name: web
          image: nginx:1.20
          ports:
            - containerPort: 80
YAML

kubectl rollout status deploy/app-v1 -n default --timeout=120s >/dev/null
