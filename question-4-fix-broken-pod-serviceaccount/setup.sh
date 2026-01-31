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

# (Re)create namespace
kubectl create namespace monitoring >/dev/null 2>&1 || true

# Reset scenario objects
kubectl delete pod metrics-pod -n monitoring --ignore-not-found
kubectl delete rolebinding monitor-binding admin-binding -n monitoring --ignore-not-found
kubectl delete role metrics-reader full-access view-only -n monitoring --ignore-not-found
kubectl delete sa monitor-sa wrong-sa admin-sa -n monitoring --ignore-not-found

# ServiceAccounts
kubectl create sa monitor-sa -n monitoring
kubectl create sa wrong-sa -n monitoring
kubectl create sa admin-sa -n monitoring

# Roles
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: metrics-reader
  namespace: monitoring
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: view-only
  namespace: monitoring
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: full-access
  namespace: monitoring
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
YAML

# RoleBindings
# Correct binding: monitor-sa -> metrics-reader
kubectl create rolebinding monitor-binding \
  --role=metrics-reader \
  --serviceaccount=monitoring:monitor-sa \
  -n monitoring

# Admin binding exists but is not the intended one for this task
kubectl create rolebinding admin-binding \
  --role=full-access \
  --serviceaccount=monitoring:admin-sa \
  -n monitoring

# Create a Pod that continuously tries to list pods in the namespace.
# With wrong-sa (no binding), it should log Forbidden errors.
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: metrics-pod
  namespace: monitoring
  labels:
    app: metrics
spec:
  serviceAccountName: wrong-sa
  restartPolicy: Always
  containers:
    - name: metrics
      image: bitnami/kubectl:1.28
      command: ["/bin/sh", "-c"]
      args:
        - |
          while true; do
            date
            kubectl get pods -n monitoring
            echo "---"
            sleep 5
          done
YAML

# Best-effort wait
kubectl wait --for=condition=Ready pod/metrics-pod -n monitoring --timeout=120s >/dev/null 2>&1 || true
