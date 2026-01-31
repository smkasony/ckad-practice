#!/usr/bin/env bash
set -euo pipefail

NS="default"
DEPLOY="api-server"
SECRET="db-credentials"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

need_cmd kubectl

if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
	fail "Namespace '${NS}' not found"
fi

if ! kubectl get deploy "${DEPLOY}" -n "${NS}" >/dev/null 2>&1; then
	fail "Deployment '${DEPLOY}' not found in namespace '${NS}'"
fi

if ! kubectl get secret "${SECRET}" -n "${NS}" >/dev/null 2>&1; then
	fail "Secret '${SECRET}' not found in namespace '${NS}'"
fi

decode_b64() {
	# Linux (GNU coreutils): base64 -d / --decode
	if base64 --help 2>/dev/null | grep -q -- '--decode'; then
		base64 --decode
	else
		base64 -d
	fi
}

get_secret_value() {
	local key="$1"
	local b64
	b64="$(kubectl get secret "${SECRET}" -n "${NS}" -o jsonpath="{.data.${key}}" 2>/dev/null || true)"
	[[ -n "${b64}" ]] || return 1
	echo "${b64}" | decode_b64
}

expected_user="admin"
expected_pass='Secret123!'

actual_user="$(get_secret_value DB_USER || true)"
actual_pass="$(get_secret_value DB_PASS || true)"

[[ "${actual_user}" == "${expected_user}" ]] || fail "Secret '${SECRET}' key DB_USER mismatch"
[[ "${actual_pass}" == "${expected_pass}" ]] || fail "Secret '${SECRET}' key DB_PASS mismatch"

check_env_secret_ref() {
	local env_name="$1"
	local expected_key="$2"

	local ref_name ref_key has_literal
	ref_name="$(kubectl get deploy "${DEPLOY}" -n "${NS}" -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"${env_name}\")].valueFrom.secretKeyRef.name}" 2>/dev/null || true)"
	ref_key="$(kubectl get deploy "${DEPLOY}" -n "${NS}" -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"${env_name}\")].valueFrom.secretKeyRef.key}" 2>/dev/null || true)"
	has_literal="$(kubectl get deploy "${DEPLOY}" -n "${NS}" -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"${env_name}\")].value}" 2>/dev/null || true)"

	[[ -z "${has_literal}" ]] || fail "Deployment '${DEPLOY}' still has a literal value for env var '${env_name}'"
	[[ "${ref_name}" == "${SECRET}" ]] || fail "Deployment '${DEPLOY}' env '${env_name}' is not referencing secret '${SECRET}'"
	[[ "${ref_key}" == "${expected_key}" ]] || fail "Deployment '${DEPLOY}' env '${env_name}' is not using key '${expected_key}'"
}

check_env_secret_ref DB_USER DB_USER
check_env_secret_ref DB_PASS DB_PASS

echo "PASS: Q1 verified (secret created and deployment uses secretKeyRef)"