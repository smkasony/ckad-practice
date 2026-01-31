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

kubectl delete ingress web-ingress -n default --ignore-not-found
kubectl delete svc web-svc -n default --ignore-not-found
kubectl delete deploy web-deploy -n default --ignore-not-found

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 8080
YAML

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: default
spec:
  selector:
    app: web
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
YAML

kubectl rollout status deploy/web-deploy -n default --timeout=120s
