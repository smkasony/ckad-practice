#!/bin/bash
set -euo pipefail

ns=network-demo

# Pods must have the expected labels
[[ "$(kubectl get pod frontend -n "$ns" -o jsonpath='{.metadata.labels.role}')" == "frontend" ]]
[[ "$(kubectl get pod backend -n "$ns" -o jsonpath='{.metadata.labels.role}')" == "backend" ]]
[[ "$(kubectl get pod database -n "$ns" -o jsonpath='{.metadata.labels.role}')" == "db" ]]

# NetworkPolicies should still exist and target the expected roles
kubectl get netpol deny-all -n "$ns" >/dev/null
kubectl get netpol allow-frontend-to-backend -n "$ns" >/dev/null
kubectl get netpol allow-backend-to-db -n "$ns" >/dev/null

# Verify selectors inside the policies (catches accidental policy edits)
[[ "$(kubectl get netpol allow-frontend-to-backend -n "$ns" -o jsonpath='{.spec.podSelector.matchLabels.role}')" == "backend" ]]
[[ "$(kubectl get netpol allow-frontend-to-backend -n "$ns" -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.role}')" == "frontend" ]]

[[ "$(kubectl get netpol allow-backend-to-db -n "$ns" -o jsonpath='{.spec.podSelector.matchLabels.role}')" == "db" ]]
[[ "$(kubectl get netpol allow-backend-to-db -n "$ns" -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.role}')" == "backend" ]]

# Pods should remain Ready
kubectl wait --for=condition=Ready pod/frontend -n "$ns" --timeout=30s >/dev/null
kubectl wait --for=condition=Ready pod/backend -n "$ns" --timeout=30s >/dev/null
kubectl wait --for=condition=Ready pod/database -n "$ns" --timeout=30s >/dev/null
