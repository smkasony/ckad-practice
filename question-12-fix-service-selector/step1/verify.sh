#!/bin/bash
set -euo pipefail

ns=default
svc=web-svc

kubectl get svc "$svc" -n "$ns" >/dev/null

selector_app=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.selector.app}')

if [[ "$selector_app" != "webapp" ]]; then
  echo "Service $svc selector app must be webapp" >&2
  exit 1
fi

# Service should have endpoints once selector matches
ip_count=$(kubectl get endpoints "$svc" -n "$ns" -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' | sed '/^$/d' | wc -l | tr -d ' ')

if [[ "$ip_count" == "0" ]]; then
  echo "Service $svc has no endpoints; selector may still be wrong" >&2
  exit 1
fi
