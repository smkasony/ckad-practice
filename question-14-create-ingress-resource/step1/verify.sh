#!/bin/bash
set -euo pipefail

ns=default
ing=web-ingress

kubectl get ingress "$ing" -n "$ns" >/dev/null

apiVersion=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.apiVersion}')
if [[ "$apiVersion" != "networking.k8s.io/v1" ]]; then
  echo "Ingress $ing must use networking.k8s.io/v1 (got: $apiVersion)" >&2
  exit 1
fi

host=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].host}')
if [[ "$host" != "web.example.com" ]]; then
  echo "Ingress $ing host must be web.example.com (got: $host)" >&2
  exit 1
fi

path=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].path}')
pathType=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].pathType}')
svc=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
port=$(kubectl get ingress "$ing" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')

if [[ "$path" != "/" ]]; then
  echo "Ingress $ing path must be / (got: $path)" >&2
  exit 1
fi

if [[ "$pathType" != "Prefix" ]]; then
  echo "Ingress $ing pathType must be Prefix (got: $pathType)" >&2
  exit 1
fi

if [[ "$svc" != "web-svc" ]]; then
  echo "Ingress $ing backend service must be web-svc (got: $svc)" >&2
  exit 1
fi

if [[ "$port" != "8080" ]]; then
  echo "Ingress $ing backend port must be 8080 (got: $port)" >&2
  exit 1
fi
