## Task

In namespace `monitoring`, Pod `metrics-pod` is using ServiceAccount `wrong-sa` and receiving authorization errors.

Multiple resources already exist in the namespace:
- ServiceAccounts: `monitor-sa`, `wrong-sa`, `admin-sa`
- Roles: `metrics-reader`, `full-access`, `view-only`
- RoleBindings: `monitor-binding`, `admin-binding`

### Your tasks
1. Identify which ServiceAccount/Role/RoleBinding combination has the correct permissions
2. Update Pod `metrics-pod` to use the correct ServiceAccount
3. Verify the Pod stops showing authorization errors

Notes:
- Expect to inspect RoleBindings and Roles.
- Pods cannot generally change `serviceAccountName` in-place; plan accordingly.
