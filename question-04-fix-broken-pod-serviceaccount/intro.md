This scenario sets up a namespace `monitoring` with multiple ServiceAccounts, Roles, and RoleBindings.

A Pod named `metrics-pod` is configured with the wrong ServiceAccount and is producing authorization errors in its logs.

Your job is to identify the correct RBAC combination and fix the Pod.
