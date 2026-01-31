## Task

File `/root/broken-deploy.yaml` contains a Deployment manifest that fails to apply.

The file has the following issues:
1. Uses a deprecated/invalid API version
2. Missing the required `selector` field for `apps/v1` Deployments
3. After adding a selector, it must match the template labels

### Your tasks
1. Fix the YAML file to use `apiVersion: apps/v1`
2. Add a proper `selector` field that matches the template labels
3. Apply the fixed manifest and ensure the Deployment is running
