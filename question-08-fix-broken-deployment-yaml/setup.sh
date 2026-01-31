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
kubectl delete deploy broken-app -n default --ignore-not-found

# Seed a broken manifest at the expected location
cat >/root/broken-deploy.yaml <<'YAML'
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: web
          image: nginx
YAML
