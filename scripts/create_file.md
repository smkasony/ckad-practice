# CKAD Practice – Q1 (Secrets)

In namespace `default`, Deployment `api-server` exists with hard-coded environment variables:

- `DB_USER=admin`
- `DB_PASS=Secret123!`

Your task:

1. Create a Secret named `db-credentials` in namespace `default` containing these credentials.
2. Update Deployment `api-server` to use the Secret via `valueFrom.secretKeyRef`.
3. Do not change the Deployment name or namespace.

## Reset / Setup (run anytime)

Run this to (re)create the unsolved starting state:

```bash
bash scripts/q1-scenario.sh
```

## Verify

KillerCoda will run the verifier automatically, but you can also run:

```bash
bash scripts/verify.sh
```