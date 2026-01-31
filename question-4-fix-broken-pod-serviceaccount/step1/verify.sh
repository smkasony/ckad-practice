#!/bin/bash
set -euo pipefail

ns=monitoring
pod=metrics-pod
expected_sa=monitor-sa

# Pod exists
kubectl get pod "$pod" -n "$ns" >/dev/null

# Ensure the intended binding exists (monitor-sa -> metrics-reader)
rb_role=$(kubectl get rolebinding monitor-binding -n "$ns" -o jsonpath='{.roleRef.kind}:{.roleRef.name}')
if [[ "$rb_role" != "Role:metrics-reader" ]]; then
  echo "rolebinding/monitor-binding is not bound to Role/metrics-reader" >&2
  exit 1
fi

subject_sa=$(kubectl get rolebinding monitor-binding -n "$ns" -o jsonpath='{.subjects[?(@.kind=="ServiceAccount")].name}')
if [[ "$subject_sa" != "$expected_sa" ]]; then
  echo "rolebinding/monitor-binding does not reference ServiceAccount/$expected_sa" >&2
  exit 1
fi

# Verify SA has list permission
can_list=$(kubectl auth can-i list pods --as="system:serviceaccount:$ns:$expected_sa" -n "$ns")
if [[ "$can_list" != "yes" ]]; then
  echo "ServiceAccount/$expected_sa does not have list pods permission" >&2
  exit 1
fi

# Pod must be updated to use the correct ServiceAccount
actual_sa=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.serviceAccountName}')
if [[ "$actual_sa" != "$expected_sa" ]]; then
  echo "Pod/$pod is using ServiceAccount/$actual_sa, expected $expected_sa" >&2
  exit 1
fi

# Pod should be ready
kubectl wait --for=condition=Ready pod/$pod -n "$ns" --timeout=120s >/dev/null

# Logs should not show Forbidden/forbidden in the most recent attempts
recent_logs=$(kubectl logs -n "$ns" "$pod" --tail=30 2>/dev/null || true)
if echo "$recent_logs" | grep -qiE 'forbidden|cannot list|Unauthorized'; then
  echo "Pod/$pod logs still show authorization errors" >&2
  exit 1
fi
