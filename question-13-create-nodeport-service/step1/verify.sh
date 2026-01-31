#!/bin/bash
set -euo pipefail

ns=default
svc=api-nodeport

kubectl get svc "$svc" -n "$ns" >/dev/null

type=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.type}')
if [[ "$type" != "NodePort" ]]; then
  echo "Service $svc must be type NodePort (got: $type)" >&2
  exit 1
fi

sel_app=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.selector.app}')
if [[ "$sel_app" != "api" ]]; then
  echo "Service $svc selector must include app=api (got app=$sel_app)" >&2
  exit 1
fi

port=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.ports[0].port}')
targetPort=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.ports[0].targetPort}')
nodePort=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.ports[0].nodePort}')

if [[ "$port" != "80" ]]; then
  echo "Service $svc must expose port 80 (got: $port)" >&2
  exit 1
fi

if [[ "$targetPort" != "9090" ]]; then
  echo "Service $svc must targetPort 9090 (got: $targetPort)" >&2
  exit 1
fi

if [[ -z "$nodePort" ]]; then
  echo "Service $svc has no nodePort assigned" >&2
  exit 1
fi

kubectl get endpoints "$svc" -n "$ns" >/dev/null
