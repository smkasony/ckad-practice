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

# Ensure namespace exists
kubectl get ns audit >/dev/null 2>&1 || kubectl create ns audit

# Reset scenario state (idempotent)
kubectl delete pod log-collector -n audit --ignore-not-found
kubectl delete rolebinding log-rb -n audit --ignore-not-found
kubectl delete role log-role -n audit --ignore-not-found
kubectl delete sa log-sa -n audit --ignore-not-found

# Create a Pod that attempts to list pods using the default service account and logs the result.
# By default, the namespace's default SA should not be allowed to list pods, so logs will show Forbidden.
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: log-collector
  namespace: audit
  labels:
    app: log-collector
spec:
  serviceAccountName: default
  restartPolicy: Always
  containers:
    - name: collector
      image: bitnami/kubectl:1.29
      command: ["/bin/sh", "-c"]
      args:
        - |
          echo "starting log-collector";
          while true; do
            if kubectl get pods -n audit >/dev/null 2>&1; then
              echo "OK: can list pods";
              kubectl get pods -n audit;
            else
              echo "ERR: cannot list pods";
              kubectl get pods -n audit 2>&1 || true;
            fi
            sleep 5;
          done
YAML

# Wait for pod to be ready-ish (best-effort)
for i in {1..60}; do
  phase=$(kubectl get pod log-collector -n audit -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "$phase" == "Running" ]]; then
    break
  fi
  sleep 2
done
