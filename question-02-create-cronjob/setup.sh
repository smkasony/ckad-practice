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

# Cleanup any previous attempt
kubectl delete job backup-job-test -n default --ignore-not-found
kubectl delete cronjob backup-job -n default --ignore-not-found
