#!/bin/bash
set -euo pipefail

ns=default
secret=db-credentials
deploy=api-server

# 1) Secret exists with required keys
kubectl get secret "$secret" -n "$ns" >/dev/null

user_b64=$(kubectl get secret "$secret" -n "$ns" -o jsonpath='{.data.DB_USER}')
pass_b64=$(kubectl get secret "$secret" -n "$ns" -o jsonpath='{.data.DB_PASS}')

if [[ -z "${user_b64}" || -z "${pass_b64}" ]]; then
  echo "Secret $secret is missing DB_USER and/or DB_PASS keys" >&2
  exit 1
fi

user_val=$(printf '%s' "$user_b64" | base64 -d 2>/dev/null || true)
pass_val=$(printf '%s' "$pass_b64" | base64 -d 2>/dev/null || true)

if [[ "$user_val" != "admin" ]]; then
  echo "Secret $secret DB_USER value is incorrect" >&2
  exit 1
fi

if [[ "$pass_val" != "Secret123!" ]]; then
  echo "Secret $secret DB_PASS value is incorrect" >&2
  exit 1
fi

# 2) Deployment env uses secretKeyRef (not hardcoded values)
ref_user_name=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_USER")].valueFrom.secretKeyRef.name}')
ref_user_key=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_USER")].valueFrom.secretKeyRef.key}')
ref_pass_name=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASS")].valueFrom.secretKeyRef.name}')
ref_pass_key=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASS")].valueFrom.secretKeyRef.key}')

hard_user=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_USER")].value}')
hard_pass=$(kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASS")].value}')

if [[ -n "$hard_user" || -n "$hard_pass" ]]; then
  echo "Deployment $deploy still contains hardcoded DB_USER/DB_PASS values" >&2
  exit 1
fi

if [[ "$ref_user_name" != "$secret" || "$ref_user_key" != "DB_USER" ]]; then
  echo "Deployment $deploy DB_USER is not sourced from $secret/DB_USER" >&2
  exit 1
fi

if [[ "$ref_pass_name" != "$secret" || "$ref_pass_key" != "DB_PASS" ]]; then
  echo "Deployment $deploy DB_PASS is not sourced from $secret/DB_PASS" >&2
  exit 1
fi

# 3) Ensure rollout is healthy
kubectl rollout status deploy/$deploy -n "$ns" --timeout=120s >/dev/null
