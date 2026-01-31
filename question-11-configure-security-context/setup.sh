#!/bin/bash
set -euo pipefail

# Wait for Kubernetes API to be reachable (Killercoda)
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

# Reset scenario state
kubectl delete deploy secure-app -n default --ignore-not-found

# Create a starting Deployment without security contexts
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args: ["sleep 3600000"]
YAML

kubectl rollout status deploy/secure-app -n default --timeout=120s
