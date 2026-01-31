Nice work.

You:
- Created a Secret `db-credentials` in `default`
- Updated Deployment `api-server` to use `valueFrom.secretKeyRef`

Tip: In the exam, prefer `kubectl create secret ...` + `kubectl edit deploy ...` or a strategic `kubectl patch`.
