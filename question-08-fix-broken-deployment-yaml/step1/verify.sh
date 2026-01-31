#!/bin/bash
set -euo pipefail

manifest=/root/broken-deploy.yaml

if [[ ! -f "$manifest" ]]; then
  echo "Missing $manifest" >&2
  exit 1
fi

# Ensure the user actually fixed the file (not just created resources another way)
grep -Eq '^apiVersion:\s*apps/v1\s*$' "$manifest" || {
  echo "Manifest still not using apiVersion: apps/v1" >&2
  exit 1
}

grep -Eq '^\s*selector:\s*$' "$manifest" || {
  echo "Manifest still missing selector" >&2
  exit 1
}

grep -Eq '^\s*matchLabels:\s*$' "$manifest" || {
  echo "Manifest selector missing matchLabels" >&2
  exit 1
}

# Apply should succeed
kubectl apply -f "$manifest" >/dev/null

# Deployment must be healthy
kubectl rollout status deploy/broken-app -n default --timeout=120s >/dev/null

# Validate selector matches template labels (for all matchLabels entries)
kubectl get deploy broken-app -n default -o json | python3 - <<'PY'
import json, sys

d = json.load(sys.stdin)
sel = (d.get('spec', {})
         .get('selector', {})
         .get('matchLabels', {}) or {})
labels = (d.get('spec', {})
            .get('template', {})
            .get('metadata', {})
            .get('labels', {}) or {})

if not sel:
    raise SystemExit("selector.matchLabels is empty")

for k, v in sel.items():
    if labels.get(k) != v:
        raise SystemExit(f"selector label {k}={v} does not match template labels")
PY
