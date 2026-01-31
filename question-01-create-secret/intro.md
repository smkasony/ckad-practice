In this scenario, a Deployment named `api-server` already exists in the `default` namespace.

It currently contains **hardcoded** environment variables:
- `DB_USER=admin`
- `DB_PASS=Secret123!`

Your goal is to move these values into a Kubernetes Secret and update the Deployment to reference the Secret.

When you are ready, proceed to the next step.
