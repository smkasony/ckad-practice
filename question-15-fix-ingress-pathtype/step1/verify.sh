#!/bin/bash
set -euo pipefail

ns=default
ing=api-ingress

kubectl get ingress "$ing" -n "$ns" >/dev/null

path=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].path}')
pathType=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].pathType}')
svc=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
port=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')

if [[ "$path" != "/api" ]]; then
  echo "Ingress $ing must route path /api (got: $path)" >&2
  exit 1
fi

case "$pathType" in
  Prefix|Exact|ImplementationSpecific) ;;
  *)
    echo "Ingress $ing has invalid pathType: $pathType" >&2
    exit 1
    ;;
esac

if [[ "$svc" != "api-svc" ]]; then
  echo "Ingress $ing backend service must be api-svc (got: $svc)" >&2
  exit 1
fi

if [[ "$port" != "8080" ]]; then
  echo "Ingress $ing backend port must be 8080 (got: $port)" >&2
  exit 1
fi
