#!/bin/bash
set -euo pipefail

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

kubectl delete svc api-nodeport -n default --ignore-not-found
kubectl delete deploy api-server -n default --ignore-not-found

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
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:1.25
          ports:
            - containerPort: 9090
YAML

kubectl rollout status deploy/api-server -n default --timeout=120s
