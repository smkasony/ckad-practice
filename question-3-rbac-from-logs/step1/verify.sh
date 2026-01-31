#!/bin/bash
set -euo pipefail

ns=audit
sa=log-sa
role=log-role
rb=log-rb
pod=log-collector

# 1) ServiceAccount exists
kubectl get sa "$sa" -n "$ns" >/dev/null

# 2) Role has correct rules
# Validate there exists at least one rule with:
# - apiGroups: [""]
# - resources: ["pods"]
# - verbs includes get/list/watch
found=false

for idx in $(seq 0 20); do
  # Stop when the indexed rule doesn't exist
  api_groups=$(kubectl get role "$role" -n "$ns" -o jsonpath="{.rules[$idx].apiGroups[*]}" 2>/dev/null || true)
  resources=$(kubectl get role "$role" -n "$ns" -o jsonpath="{.rules[$idx].resources[*]}" 2>/dev/null || true)
  verbs=$(kubectl get role "$role" -n "$ns" -o jsonpath="{.rules[$idx].verbs[*]}" 2>/dev/null || true)

  if [[ -z "$api_groups" && -z "$resources" && -z "$verbs" ]]; then
    continue
  fi

  has_core=false
  if [[ -z "$api_groups" ]]; then
    # Core apiGroup is represented as empty string, which jsonpath often prints as empty.
    has_core=true
  else
    # If printed, it must be exactly "".
    if echo "$api_groups" | tr ' ' '\n' | grep -qx '""'; then
      has_core=true
    fi
  fi

  if [[ "$has_core" != true ]]; then
    continue
  fi

  if ! echo "$resources" | tr ' ' '\n' | grep -qx "pods"; then
    continue
  fi

  missing=false
  for v in get list watch; do
    if ! echo "$verbs" | tr ' ' '\n' | grep -qx "$v"; then
      missing=true
      break
    fi
  done

  if [[ "$missing" == false ]]; then
    found=true
    break
  fi
done

if [[ "$found" != true ]]; then
  echo "Role $role does not include a rule granting get/list/watch on pods in the core API group" >&2
  exit 1
fi

# 3) RoleBinding binds role -> serviceaccount
kubectl get rolebinding "$rb" -n "$ns" >/dev/null

rb_role_name=$(kubectl get rolebinding "$rb" -n "$ns" -o jsonpath='{.roleRef.name}')
rb_role_kind=$(kubectl get rolebinding "$rb" -n "$ns" -o jsonpath='{.roleRef.kind}')

if [[ "$rb_role_kind" != "Role" || "$rb_role_name" != "$role" ]]; then
  echo "RoleBinding $rb does not reference Role $role" >&2
  exit 1
fi

rb_subject_match=$(kubectl get rolebinding "$rb" -n "$ns" -o jsonpath='{range .subjects[*]}{.kind}{"|"}{.name}{"|"}{.namespace}{"\n"}{end}' | grep -E "^ServiceAccount\|${sa}\|${ns}$" || true)
if [[ -z "$rb_subject_match" ]]; then
  echo "RoleBinding $rb does not bind ServiceAccount ${ns}:${sa}" >&2
  exit 1
fi

# 4) Pod uses log-sa
pod_sa=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.serviceAccountName}')
if [[ "$pod_sa" != "$sa" ]]; then
  echo "Pod $pod is using serviceAccountName=$pod_sa (expected $sa)" >&2
  exit 1
fi

# 5) Logs show the permission issue is resolved
# We consider it resolved if recent logs contain OK and do not contain the known forbidden indicator.
logs=$(kubectl logs -n "$ns" "$pod" --tail=30 2>/dev/null || true)

if ! echo "$logs" | grep -q "OK: can list pods"; then
  echo "Pod logs do not yet show successful access" >&2
  exit 1
fi

if echo "$logs" | grep -qi "cannot list"; then
  echo "Pod logs still show authorization errors" >&2
  exit 1
fi

# Also ensure pod is running
phase=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.status.phase}')
if [[ "$phase" != "Running" ]]; then
  echo "Pod $pod is not Running (phase=$phase)" >&2
  exit 1
fi
