#!/bin/bash
set -euo pipefail

ns=default
deploy=app-v1

kubectl get deploy "$deploy" -n "$ns" >/dev/null
kubectl rollout status deploy/$deploy -n "$ns" --timeout=120s >/dev/null

# Final state must be rolled back to nginx:1.20
current_image=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[?(@.name=="web")].image}')
if [[ "$current_image" != "nginx:1.20" ]]; then
  echo "Expected current image to be nginx:1.20 after rollback, got: $current_image" >&2
  exit 1
fi

# Prove that an update to nginx:1.25 occurred by checking historical ReplicaSets
kubectl get rs -n "$ns" -l app=app-v1 -o json | python3 - <<'PY'
import json, sys

data = json.load(sys.stdin)
items = data.get('items', [])
images = set()
for rs in items:
    tpl = rs.get('spec', {}).get('template', {})
    containers = tpl.get('spec', {}).get('containers', []) or []
    for c in containers:
        img = c.get('image')
        if img:
            images.add(img)

if 'nginx:1.25' not in images:
    raise SystemExit('No ReplicaSet found with image nginx:1.25 (update step not detected)')
PY

# Ensure deployment is available
available=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.status.availableReplicas}')
if [[ -z "$available" || "$available" -lt 1 ]]; then
  echo "Deployment is not available" >&2
  exit 1
fi
