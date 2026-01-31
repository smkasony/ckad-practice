## Task

In namespace `audit`, Pod `log-collector` exists but is failing with authorization errors.

Check the Pod logs to identify what permissions are needed.

### Requirements
1. Create a ServiceAccount named `log-sa` in namespace `audit`
2. Create a Role `log-role` that grants `get`, `list`, and `watch` on resource `pods`
3. Create a RoleBinding `log-rb` binding `log-role` to `log-sa`
4. Update Pod `log-collector` to use ServiceAccount `log-sa`

### Notes
- Use the logs to confirm the identity that is being denied.
- Remember: many Pod fields (including `serviceAccountName`) are immutable; you may need to recreate the Pod.
