#!/bin/bash
set -euo pipefail

# Wait for the cluster
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

# Clean previous runs
kubectl delete deploy web-app web-app-canary -n default --ignore-not-found
kubectl delete svc web-service -n default --ignore-not-found

# Create the baseline Deployment (v1)
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 5
  selector:
    matchLabels:
      app: webapp
      version: v1
  template:
    metadata:
      labels:
        app: webapp
        version: v1
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
YAML

# Create the Service selecting both versions via app=webapp
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: default
spec:
  selector:
    app: webapp
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

kubectl rollout status deploy/web-app -n default --timeout=180s
