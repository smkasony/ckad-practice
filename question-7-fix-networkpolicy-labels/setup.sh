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

ns=network-demo

kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns" >/dev/null

# Reset only scenario resources
kubectl delete pod frontend backend database -n "$ns" --ignore-not-found
kubectl delete netpol deny-all allow-frontend-to-backend allow-backend-to-db -n "$ns" --ignore-not-found

# Create pods with incorrect labels
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: network-demo
  labels:
    role: wrong-frontend
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args: ["sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: network-demo
  labels:
    role: wrong-backend
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args: ["sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  namespace: network-demo
  labels:
    role: wrong-db
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args: ["sleep 3600"]
YAML

kubectl wait --for=condition=Ready pod/frontend -n "$ns" --timeout=120s >/dev/null
kubectl wait --for=condition=Ready pod/backend -n "$ns" --timeout=120s >/dev/null
kubectl wait --for=condition=Ready pod/database -n "$ns" --timeout=120s >/dev/null

# Create NetworkPolicies that expect role=frontend, role=backend, role=db
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: network-demo
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: network-demo
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: network-demo
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: backend
YAML
