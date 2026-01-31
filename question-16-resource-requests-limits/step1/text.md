## Task

In namespace `prod`, a ResourceQuota exists that sets resource limits for the namespace.

Your tasks:
1. Inspect the ResourceQuota in namespace `prod` to determine the configured limits
2. Create a Pod named `resource-pod` with:
   - Image: `nginx:latest`
   - CPU and memory limits set to **half** of the quota limits
   - Requests set to at least `100m` CPU and `128Mi` memory

Note: Adjust your values to match the quota you find.
