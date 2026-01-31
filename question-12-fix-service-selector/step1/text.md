## Task

In namespace `default`, Deployment `web-app` exists with Pods labeled:
- `app=webapp`
- `tier=frontend`

Service `web-svc` exists but has an incorrect selector `app=wrongapp`.

Your task:
- Update Service `web-svc` so it correctly selects the Pods from Deployment `web-app`.
