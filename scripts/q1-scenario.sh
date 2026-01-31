#!/usr/bin/env bash
set -euo pipefail

# CKAD Practice - Question 1 Scenario Setup
# Creates a Deployment `api-server` in namespace `default` with hard-coded env vars:
#   DB_USER=admin
#   DB_PASS=Secret123!
#
# This script intentionally DOES NOT create the Secret or fix the Deployment.

NS="default"
DEPLOY="api-server"
SECRET="db-credentials"

if ! command -v kubectl >/dev/null 2>&1; then
	echo "ERROR: kubectl not found in PATH" >&2
	exit 1
fi

if ! kubectl version --client >/dev/null 2>&1; then
	echo "ERROR: kubectl is not working" >&2
	exit 1
fi

if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
	echo "ERROR: Namespace '${NS}' does not exist" >&2
	exit 1
fi

echo "[q1] Preparing scenario in namespace '${NS}'..."

# Ensure the scenario starts unsolved.
kubectl delete secret "${SECRET}" -n "${NS}" --ignore-not-found

# Recreate the deployment in a known state.
kubectl delete deploy "${DEPLOY}" -n "${NS}" --ignore-not-found

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:

  name: ${DEPLOY}
  namespace: ${NS}
  labels:
    app: api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          env:
            - name: DB_USER
              value: "admin"
            - name: DB_PASS
              value: "Secret123!"
EOF

echo "[q1] Waiting for deployment to become ready..."
kubectl rollout status deploy "${DEPLOY}" -n "${NS}"

echo
echo "[q1] Scenario ready. Starting state (hardcoded env vars):"
echo "  kubectl get deploy ${DEPLOY} -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env}' ; echo"
echo "  kubectl get secret ${SECRET} -n ${NS}  # should NOT exist"

echo
echo "[q1] Your task (CKAD-style):"
echo "  1) Create secret '${SECRET}' in '${NS}' with keys DB_USER and DB_PASS"
echo "  2) Update deploy '${DEPLOY}' to use valueFrom.secretKeyRef for both env vars"
echo "  3) Keep name/namespace unchanged"

