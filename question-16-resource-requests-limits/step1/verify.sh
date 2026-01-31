#!/bin/bash
set -euo pipefail

ns=prod
pod=resource-pod

cpu_to_m() {
  local cpu="$1"
  if [[ -z "$cpu" ]]; then
    echo 0
    return
  fi
  if [[ "$cpu" =~ ^[0-9]+m$ ]]; then
    echo "${cpu%m}"
    return
  fi
  if [[ "$cpu" =~ ^[0-9]+$ ]]; then
    echo $(( cpu * 1000 ))
    return
  fi
  # Best-effort for decimals like 0.5
  if [[ "$cpu" =~ ^[0-9]+\.[0-9]+$ ]]; then
    python3 - <<PY
import sys
v=float(sys.argv[1])
print(int(v*1000))
PY
"$cpu"
    return
  fi
  echo 0
}

mem_to_mi() {
  local mem="$1"
  if [[ -z "$mem" ]]; then
    echo 0
    return
  fi
  if [[ "$mem" =~ ^[0-9]+Mi$ ]]; then
    echo "${mem%Mi}"
    return
  fi
  if [[ "$mem" =~ ^[0-9]+Gi$ ]]; then
    local gi="${mem%Gi}"
    echo $(( gi * 1024 ))
    return
  fi
  if [[ "$mem" =~ ^[0-9]+$ ]]; then
    # bytes; rough convert
    python3 - <<PY
import sys
v=int(sys.argv[1])
print(int(v/1024/1024))
PY
"$mem"
    return
  fi
  echo 0
}

kubectl get pod "$pod" -n "$ns" >/dev/null

image=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].image}')
if [[ "$image" != "nginx:latest" ]]; then
  echo "Pod $pod must use image nginx:latest (got: $image)" >&2
  exit 1
fi

# Quota is fixed by setup.sh: half of 2 CPU and 4Gi memory.
exp_cpu_limit_m=1000
exp_mem_limit_mi=2048

req_cpu=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
req_mem=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.requests.memory}')
lim_cpu=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
lim_mem=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.limits.memory}')

req_cpu_m=$(cpu_to_m "$req_cpu")
lim_cpu_m=$(cpu_to_m "$lim_cpu")
req_mem_mi=$(mem_to_mi "$req_mem")
lim_mem_mi=$(mem_to_mi "$lim_mem")

if (( req_cpu_m < 100 )); then
  echo "CPU request must be at least 100m (got: ${req_cpu:-<empty>})" >&2
  exit 1
fi

if (( req_mem_mi < 128 )); then
  echo "Memory request must be at least 128Mi (got: ${req_mem:-<empty>})" >&2
  exit 1
fi

if (( lim_cpu_m != exp_cpu_limit_m )); then
  echo "CPU limit must be half of quota (expected 1000m, got: ${lim_cpu:-<empty>})" >&2
  exit 1
fi

if (( lim_mem_mi != exp_mem_limit_mi )); then
  echo "Memory limit must be half of quota (expected 2Gi/2048Mi, got: ${lim_mem:-<empty>})" >&2
  exit 1
fi
