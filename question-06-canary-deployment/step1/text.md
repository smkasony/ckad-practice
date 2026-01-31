## Task

In namespace `default`, the following resources exist:
- Deployment `web-app` with 5 replicas, labels `app=webapp, version=v1`
- Service `web-service` with selector `app=webapp`

### Your tasks
1. Scale Deployment `web-app` to 8 replicas
2. Create a new Deployment `web-app-canary` with 2 replicas, labels `app=webapp, version=v2`
3. Ensure **both** Deployments are selected by `web-service`

Notes:
- This is a manual canary pattern where traffic is split by replica counts.
- Do not change the Service selector.
