## Task

In namespace `network-demo`, three Pods exist:
- `frontend` with label `role=wrong-frontend`
- `backend` with label `role=wrong-backend`
- `database` with label `role=wrong-db`

Three NetworkPolicies exist:
- `deny-all` (default deny)
- `allow-frontend-to-backend` (allows traffic from `role=frontend` to `role=backend`)
- `allow-backend-to-db` (allows traffic from `role=backend` to `role=db`)

### Your task
Update the Pod labels (do **NOT** modify NetworkPolicies) to enable the communication chain:

`frontend` → `backend` → `database`
