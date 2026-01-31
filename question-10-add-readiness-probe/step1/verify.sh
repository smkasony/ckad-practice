#!/bin/bash
set -euo pipefail

ns=default
deploy=api-deploy

# Ensure deployment exists
kubectl get deploy "$deploy" -n "$ns" >/dev/null

# Validate readinessProbe fields
path=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')
port=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')
initialDelay=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.initialDelaySeconds}')
period=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.periodSeconds}')

if [[ "$path" != "/ready" ]]; then
  echo "readinessProbe.httpGet.path must be /ready" >&2
  exit 1
fi

# jsonpath may return int or string; compare as string
if [[ "$port" != "8080" ]]; then
  echo "readinessProbe.httpGet.port must be 8080" >&2
  exit 1
fi

if [[ "$initialDelay" != "5" ]]; then
  echo "readinessProbe.initialDelaySeconds must be 5" >&2
  exit 1
fi

if [[ "$period" != "10" ]]; then
  echo "readinessProbe.periodSeconds must be 10" >&2
  exit 1
fi

kubectl rollout status deploy/$deploy -n "$ns" --timeout=120s >/dev/null
