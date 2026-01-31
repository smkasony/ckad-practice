## Task

In namespace `default`, a Deployment `api-server` exists with hard-coded environment variables:
- `DB_USER=admin`
- `DB_PASS=Secret123!`

### Your tasks
1. Create a Secret named `db-credentials` in namespace `default` containing these credentials
2. Update Deployment `api-server` to use the Secret via `valueFrom.secretKeyRef`
3. Do **not** change the Deployment name or namespace

---

## Helpful commands

Create the secret:

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS='Secret123!' \
  -n default
```

Edit the Deployment:

```bash
kubectl edit deploy api-server -n default
```

Replace hardcoded env vars with:

```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_USER
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_PASS
```

Verify rollout:

```bash
kubectl rollout status deploy api-server -n default
```
