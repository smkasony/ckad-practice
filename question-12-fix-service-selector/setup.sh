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
kubectl delete svc web-svc -n default --ignore-not-found
kubectl delete deploy web-app -n default --ignore-not-found

# Create Deployment with expected labels
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      tier: frontend
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
YAML

# Create Service with wrong selector
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: default
spec:
  selector:
    app: wrongapp
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
YAML

kubectl rollout status deploy/web-app -n default --timeout=120s
