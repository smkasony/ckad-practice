## Task

In namespace `default`, a Deployment `api-server` exists with hard-coded environment variables:
- `DB_USER=admin`
- `DB_PASS=Secret123!`

### Your tasks
1. Create a Secret named `db-credentials` in namespace `default` containing these credentials
2. Update Deployment `api-server` to use the Secret via `valueFrom.secretKeyRef`
3. Do **not** change the Deployment name or namespace
