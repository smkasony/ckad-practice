## Task

In namespace `default`, Deployment `api-deploy` exists with a container listening on port `8080`.

Add a readiness probe to the Deployment with:
- HTTP GET on path `/ready`
- Port `8080`
- `initialDelaySeconds: 5`
- `periodSeconds: 10`

Ensure the Deployment rolls out successfully.
