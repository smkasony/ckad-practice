## Task

In namespace `default`, Deployment `api-server` exists with Pods labeled `app=api` and container port `9090`.

Create a Service named `api-nodeport` that:
- Is type `NodePort`
- Selects Pods with label `app=api`
- Exposes Service port `80` mapping to target port `9090`

Do not rename the Deployment.
