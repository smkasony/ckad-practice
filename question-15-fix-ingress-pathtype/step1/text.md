## Task

A file exists at `/root/fix-ingress.yaml` containing an Ingress manifest that fails to apply because `pathType` is invalid.

Your tasks:
1. Fix `pathType` to a valid value (`Prefix`, `Exact`, or `ImplementationSpecific`)
2. Ensure the Ingress routes path `/api` to Service `api-svc` on port `8080`
3. Apply the fixed manifest successfully

Do not rename the Service.
