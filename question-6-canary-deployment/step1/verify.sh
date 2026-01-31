#!/bin/bash
set -euo pipefail

ns=default

# Deployments must exist
kubectl get deploy web-app -n "$ns" >/dev/null
kubectl get deploy web-app-canary -n "$ns" >/dev/null

# Replicas must match the requested split
rep_v1=$(kubectl get deploy web-app -n "$ns" -o jsonpath='{.spec.replicas}')
rep_v2=$(kubectl get deploy web-app-canary -n "$ns" -o jsonpath='{.spec.replicas}')

if [[ "$rep_v1" != "8" ]]; then
  echo "Deployment web-app replicas expected 8, got $rep_v1" >&2
  exit 1
fi

if [[ "$rep_v2" != "2" ]]; then
  echo "Deployment web-app-canary replicas expected 2, got $rep_v2" >&2
  exit 1
fi

# Service selector must be app=webapp (and must not include version)
sel_app=$(kubectl get svc web-service -n "$ns" -o jsonpath='{.spec.selector.app}')
sel_ver=$(kubectl get svc web-service -n "$ns" -o jsonpath='{.spec.selector.version}' 2>/dev/null || true)

if [[ "$sel_app" != "webapp" ]]; then
  echo "Service web-service selector app expected webapp, got $sel_app" >&2
  exit 1
fi

if [[ -n "$sel_ver" ]]; then
  echo "Service web-service selector must not include version" >&2
  exit 1
fi

# Canary labels/selector must be app=webapp, version=v2
c_sel_app=$(kubectl get deploy web-app-canary -n "$ns" -o jsonpath='{.spec.selector.matchLabels.app}')
c_sel_ver=$(kubectl get deploy web-app-canary -n "$ns" -o jsonpath='{.spec.selector.matchLabels.version}')
c_tpl_app=$(kubectl get deploy web-app-canary -n "$ns" -o jsonpath='{.spec.template.metadata.labels.app}')
c_tpl_ver=$(kubectl get deploy web-app-canary -n "$ns" -o jsonpath='{.spec.template.metadata.labels.version}')

if [[ "$c_sel_app" != "webapp" || "$c_sel_ver" != "v2" || "$c_tpl_app" != "webapp" || "$c_tpl_ver" != "v2" ]]; then
  echo "web-app-canary must have selector/template labels app=webapp, version=v2" >&2
  exit 1
fi

# v1 deployment must still be version=v1
v1_sel_ver=$(kubectl get deploy web-app -n "$ns" -o jsonpath='{.spec.selector.matchLabels.version}')
if [[ "$v1_sel_ver" != "v1" ]]; then
  echo "web-app selector version expected v1, got $v1_sel_ver" >&2
  exit 1
fi

# Ensure pods are Ready
kubectl rollout status deploy/web-app -n "$ns" --timeout=180s >/dev/null
kubectl rollout status deploy/web-app-canary -n "$ns" --timeout=180s >/dev/null

# Endpoints should include both versions
v1_ready=$(kubectl get pods -n "$ns" -l app=webapp,version=v1 -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c '^true$' || true)
v2_ready=$(kubectl get pods -n "$ns" -l app=webapp,version=v2 -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c '^true$' || true)

if [[ "$v1_ready" -lt 1 || "$v2_ready" -lt 1 ]]; then
  echo "Expected at least one Ready pod for both v1 and v2" >&2
  exit 1
fi

# Confirm the service has endpoints
endpoints=$(kubectl get endpoints web-service -n "$ns" -o jsonpath='{.subsets[*].addresses[*].ip}' || true)
if [[ -z "$endpoints" ]]; then
  echo "Service web-service has no endpoints" >&2
  exit 1
fi
