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

kubectl create namespace prod >/dev/null 2>&1 || true

kubectl delete pod resource-pod -n prod --ignore-not-found
kubectl delete quota prod-quota -n prod --ignore-not-found

# Quota chosen to be easy to halve:
# - limits.cpu: 2
# - limits.memory: 4Gi
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: prod
spec:
  hard:
    limits.cpu: "2"
    limits.memory: "4Gi"
YAML
