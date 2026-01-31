## Task

In namespace `default`, the following resources exist:
- Deployment `web-deploy` with Pods labeled `app=web`
- Service `web-svc` with selector `app=web` on port `8080`

Create an Ingress named `web-ingress` that:
- Routes host `web.example.com`
- Path `/` with `pathType: Prefix`
- Backend Service `web-svc` on port `8080`
- Uses API version `networking.k8s.io/v1`
