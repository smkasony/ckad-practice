In this scenario, a `web-service` Service already exists and selects Pods by label `app=webapp`.

A Deployment `web-app` also exists and currently serves version `v1`.

Your goal is to scale `web-app` and create a second canary Deployment so the Service routes to both.
