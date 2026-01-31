#!/bin/bash
set -euo pipefail

ns=default
deploy=secure-app

kubectl get deploy "$deploy" -n "$ns" >/dev/null

runAsUser=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.securityContext.runAsUser}')

if [[ "$runAsUser" != "1000" ]]; then
  echo "Pod-level securityContext.runAsUser must be 1000" >&2
  exit 1
fi

# Ensure container named "app" exists
kubectl get deploy "$deploy" -n "$ns" -o json | grep -q '"name":"app"'

# Check NET_ADMIN capability present in container securityContext
capAdd=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[?(@.name=="app")].securityContext.capabilities.add[*]}')

if ! printf '%s' "$capAdd" | grep -q 'NET_ADMIN'; then
  echo "Container app must have NET_ADMIN in securityContext.capabilities.add" >&2
  exit 1
fi

kubectl rollout status deploy/$deploy -n "$ns" --timeout=120s >/dev/null
