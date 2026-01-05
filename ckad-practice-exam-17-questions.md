# CKAD Practice Questions 

---

## Table of Contents

- [Question 1 – Create Secret from Hardcoded Variables](#question-1)
- [Question 2 – Create CronJob with Schedule and History Limits](#question-2)
- [Question 3 – Create ServiceAccount, Role, and RoleBinding from Logs Error](#question-3)
- [Question 4 – Fix Broken Pod with Correct ServiceAccount](#question-4)
- [Question 5 – Build Container Image with Podman and Save as Tarball](#question-5)
- [Question 6 – Create Canary Deployment with Manual Traffic Split](#question-6)
- [Question 7 – Fix NetworkPolicy by Updating Pod Labels](#question-7)
- [Question 8 – Fix Broken Deployment YAML](#question-8)
- [Question 9 – Perform Rolling Update and Rollback](#question-9)
- [Question 10 – Add Readiness Probe to Deployment](#question-10)
- [Question 11 – Configure Pod and Container Security Context](#question-11)
- [Question 12 – Fix Service Selector](#question-12)
- [Question 13 – Create NodePort Service](#question-13)
- [Question 14 – Create Ingress Resource](#question-14)
- [Question 15 – Fix Ingress PathType](#question-15)
- [Question 16 – Add Resource Requests and Limits to Pod](#question-16)

---

<a id="question-1"></a>
## Question 1 – Create Secret from Hardcoded Variables

In namespace `default`, Deployment `api-server` exists with hard-coded environment variables:
- `DB_USER=admin`
- `DB_PASS=Secret123!`

Your task:
1. Create a Secret named `db-credentials` in namespace `default` containing these credentials
2. Update Deployment `api-server` to use the Secret via `valueFrom.secretKeyRef`
3. Do not change the Deployment name or namespace

### Solution

**Step 1 – Create the Secret**

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=Secret123! \
  -n default
```

**Step 2 – Update Deployment to use Secret**

```bash
kubectl edit deploy api-server -n default
```

Replace the hardcoded environment variables:

```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_USER
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_PASS
```

Save and exit. Verify the rollout:

```bash
kubectl rollout status deploy api-server -n default
```

**Why this works**

- Secrets externalize sensitive data from Pod specifications
- Using `valueFrom.secretKeyRef` injects Secret values as environment variables
- The Deployment will automatically roll out new Pods with the updated configuration

**Docs**

- Secrets: https://kubernetes.io/docs/concepts/configuration/secret/

---

<a id="question-2"></a>
## Question 2 – Create CronJob with Schedule and History Limits

Create a CronJob named `backup-job` in namespace `default` with the following specifications:

- Schedule: Run every 30 minutes (`*/30 * * * *`)
- Image: `busybox:latest`
- Container command: `echo "Backup completed"`
- Set `successfulJobsHistoryLimit: 3`
- Set `failedJobsHistoryLimit: 2`
- Set `activeDeadlineSeconds: 300`
- Use `restartPolicy: Never`

**Tip:** Use `kubectl explain cronjob.spec` to find the correct field names.

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
  namespace: default
spec:
  schedule: "*/30 * * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      activeDeadlineSeconds: 300
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: backup
              image: busybox:latest
              command: ["/bin/sh", "-c"]
              args: ["echo Backup completed"]
EOF
```

Verify the CronJob:

```bash
kubectl get cronjob backup-job
kubectl describe cronjob backup-job
```

To test immediately, create a Job from the CronJob:

```bash
kubectl create job backup-job-test --from=cronjob/backup-job
kubectl logs job/backup-job-test
```

**Why this works**

- `schedule: "*/30 * * * *"` runs every 30 minutes
- History limits control how many completed/failed Jobs are retained
- `activeDeadlineSeconds` sets maximum time a Job can run
- `restartPolicy: Never` is required for Jobs

**Docs**

- CronJobs: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/

---

<a id="question-3"></a>
## Question 3 – Create ServiceAccount, Role, and RoleBinding from Logs Error

In namespace `audit`, Pod `log-collector` exists but is failing with authorization errors.

Check the Pod logs to identify what permissions are needed:

```bash
kubectl logs -n audit log-collector
```

The logs show: `User "system:serviceaccount:audit:default" cannot list pods in the namespace "audit"`

Your task:
1. Create a ServiceAccount named `log-sa` in namespace `audit`
2. Create a Role `log-role` that grants `get`, `list`, and `watch` on resource `pods`
3. Create a RoleBinding `log-rb` binding `log-role` to `log-sa`
4. Update Pod `log-collector` to use ServiceAccount `log-sa`

### Solution

**Step 1 – Create ServiceAccount**

```bash
kubectl create sa log-sa -n audit
```

**Step 2 – Create Role**

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: log-role
  namespace: audit
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
EOF
```

**Step 3 – Create RoleBinding**

```bash
kubectl create rolebinding log-rb \
  --role=log-role \
  --serviceaccount=audit:log-sa \
  -n audit
```

**Step 4 – Update Pod to use ServiceAccount**

Since Pods have immutable `serviceAccountName`, delete and recreate:

```bash
kubectl get pod log-collector -n audit -o yaml > /tmp/log-collector.yaml
```

Edit the file to change:
- `spec.serviceAccountName: log-sa`
- Remove `spec.serviceAccount` if present

Then:

```bash
kubectl delete pod log-collector -n audit
kubectl apply -f /tmp/log-collector.yaml
```

Or use patch if the Pod allows it (may fail due to immutability):

```bash
kubectl patch pod log-collector -n audit \
  -p '{"spec":{"serviceAccountName":"log-sa"}}'
```

If patch fails, delete and recreate.

**Why this works**

- Pod logs reveal the exact permission needed (`list pods`)
- Role grants the required permissions in the namespace
- RoleBinding connects the Role to the ServiceAccount
- ServiceAccount must be set on the Pod for RBAC to apply

**Docs**

- RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

---

<a id="question-4"></a>
## Question 4 – Fix Broken Pod with Correct ServiceAccount

In namespace `monitoring`, Pod `metrics-pod` is using ServiceAccount `wrong-sa` and receiving authorization errors.

Multiple ServiceAccounts, Roles, and RoleBindings already exist in the namespace:
- ServiceAccounts: `monitor-sa`, `wrong-sa`, `admin-sa`
- Roles: `metrics-reader`, `full-access`, `view-only`
- RoleBindings: `monitor-binding`, `admin-binding`

Your task:
1. Identify which ServiceAccount/Role/RoleBinding combination has the correct permissions
2. Update Pod `metrics-pod` to use the correct ServiceAccount
3. Verify the Pod stops showing authorization errors

**Hint:** Check existing RoleBindings to see which ServiceAccount is bound to which Role.

### Solution

**Step 1 – Investigate existing RBAC resources**

```bash
kubectl get rolebindings -n monitoring -o yaml
kubectl get roles -n monitoring -o yaml
```

Look for a RoleBinding that binds a ServiceAccount to a Role with appropriate permissions. For example:

```bash
kubectl describe rolebinding monitor-binding -n monitoring
kubectl describe role metrics-reader -n monitoring
```

If `monitor-binding` binds `monitor-sa` to `metrics-reader`, and `metrics-reader` has the needed permissions, use `monitor-sa`.

**Step 2 – Update Pod**

Delete and recreate with correct ServiceAccount:

```bash
kubectl get pod metrics-pod -n monitoring -o yaml > /tmp/metrics-pod.yaml
# Edit to change serviceAccountName to monitor-sa
kubectl delete pod metrics-pod -n monitoring
kubectl apply -f /tmp/metrics-pod.yaml
```

**Step 3 – Verify**

```bash
kubectl logs metrics-pod -n monitoring
# Should no longer show authorization errors
```

**Why this works**

- Examining existing RoleBindings shows which ServiceAccount has which permissions
- Changing the Pod's ServiceAccount to one with correct permissions fixes the issue
- No need to create new resources when existing ones work

**Docs**

- ServiceAccounts: https://kubernetes.io/docs/concepts/security/service-accounts/

---

<a id="question-5"></a>
## Question 5 – Build Container Image with Podman and Save as Tarball

On the node, directory `/root/app-source` contains a valid `Dockerfile`.

Your task:
1. Build a container image using Podman with name `my-app:1.0` using `/root/app-source` as build context
2. Save the image as a tarball to `/root/my-app.tar`

**Note:** The exam environment uses Podman, not Docker. Use `podman` commands.

### Solution

**Step 1 – Build the image**

```bash
cd /root/app-source
podman build -t my-app:1.0 .
```

Verify the image was created:

```bash
podman images | grep my-app
```

**Step 2 – Save image as tarball**

```bash
podman save --format oci-archive -o /root/my-app.tar my-app:1.0
```

Verify the file was created:

```bash
ls -lh /root/my-app.tar
```

**Why this works**

- `podman build` works like `docker build` but uses Podman runtime
- `podman save` exports the image to a tarball archive
- `--format oci-archive` creates a standard OCI archive format
- The saved tarball can be loaded on another system with `podman load`

**Docs**

- Podman: https://docs.podman.io/

---

<a id="question-6"></a>
## Question 6 – Create Canary Deployment with Manual Traffic Split

In namespace `default`, the following resources exist:
- Deployment `web-app` with 5 replicas, labels `app=webapp, version=v1`
- Service `web-service` with selector `app=webapp`

Your task:
1. Scale Deployment `web-app` to 8 replicas (80% of 10 total)
2. Create a new Deployment `web-app-canary` with 2 replicas, labels `app=webapp, version=v2`
3. Both Deployments should be selected by `web-service`
4. Verify the traffic split using the provided test command (if available)

**Note:** This is a manual canary pattern where traffic is split based on replica counts.

### Solution

**Step 1 – Scale existing Deployment**

```bash
kubectl scale deploy web-app --replicas=8 -n default
```

**Step 2 – Export and create canary Deployment**

Export the existing Deployment:

```bash
kubectl get deploy web-app -n default -o yaml > /tmp/web-app-canary.yaml
```

Edit the file to change:
- `metadata.name: web-app-canary`
- `spec.replicas: 2`
- `spec.template.metadata.labels.version: v2`
- `spec.selector.matchLabels.version: v2`
- Keep `app=webapp` label on both selector and template

Apply:

```bash
kubectl apply -f /tmp/web-app-canary.yaml
```

Or create directly:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-canary
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
      version: v2
  template:
    metadata:
      labels:
        app: webapp
        version: v2
    spec:
      containers:
        - name: web
          image: nginx:latest
EOF
```

**Step 3 – Verify Service selects both**

```bash
kubectl get endpoints web-service -n default
kubectl get pods -n default -l app=webapp --show-labels
```

Both `version=v1` and `version=v2` pods should appear in endpoints.

**Step 4 – Test traffic split (if curl available)**

```bash
# Run multiple requests to see distribution
for i in {1..10}; do
  kubectl exec -it <pod-name> -n default -- curl http://web-service
done
```

**Why this works**

- Both Deployments share the `app=webapp` label, so `web-service` selects both
- 8 v1 replicas + 2 v2 replicas = 80/20 traffic split
- Service distributes traffic across all matching pods (round-robin by default)

**Docs**

- Deployments: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

---

<a id="question-7"></a>
## Question 7 – Fix NetworkPolicy by Updating Pod Labels

In namespace `network-demo`, three Pods exist:
- `frontend` with label `role=wrong-frontend`
- `backend` with label `role=wrong-backend`
- `database` with label `role=wrong-db`

Three NetworkPolicies exist:
- `deny-all` (default deny)
- `allow-frontend-to-backend` (allows traffic from `role=frontend` to `role=backend`)
- `allow-backend-to-db` (allows traffic from `role=backend` to `role=db`)

Your task:
Update the Pod labels (do NOT modify NetworkPolicies) to enable the communication chain:
`frontend` → `backend` → `database`

**Time Saver Tip:** Use `kubectl label` instead of editing YAML and recreating Pods.

### Solution

**Step 1 – View existing NetworkPolicies**

```bash
kubectl get networkpolicies -n network-demo -o yaml
```

Identify the label selectors used in the NetworkPolicies (likely `role=frontend`, `role=backend`, `role=db`).

**Step 2 – Update Pod labels**

```bash
kubectl label pod frontend -n network-demo role=frontend --overwrite
kubectl label pod backend -n network-demo role=backend --overwrite
kubectl label pod database -n network-demo role=db --overwrite
```

Verify:

```bash
kubectl get pods -n network-demo --show-labels
```

**Step 3 – Verify NetworkPolicy rules**

```bash
kubectl describe networkpolicy allow-frontend-to-backend -n network-demo
kubectl describe networkpolicy allow-backend-to-db -n network-demo
```

**Why this works**

- NetworkPolicies use label selectors to identify source and destination Pods
- Updating Pod labels to match NetworkPolicy selectors enables the rules
- Using `kubectl label --overwrite` is faster than editing YAML and recreating
- Pods don't need to be recreated for label changes to take effect

**Docs**

- NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/network-policy/

---

<a id="question-8"></a>
## Question 8 – Fix Broken Deployment YAML

File `/root/broken-deploy.yaml` contains a Deployment manifest that fails to apply.

The file has the following issues:
1. Uses deprecated API version
2. Missing required `selector` field
3. Selector doesn't match template labels

Your task:
1. Fix the YAML file to use `apiVersion: apps/v1`
2. Add a proper `selector` field that matches the template labels
3. Apply the fixed manifest and ensure the Deployment is running

### Solution

**Step 1 – View the broken file**

```bash
cat /root/broken-deploy.yaml
```

You'll likely see something like:

```yaml
apiVersion: extensions/v1beta1  # Deprecated
kind: Deployment
metadata:
  name: broken-app
spec:
  replicas: 2
  template:  # Missing selector
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: web
          image: nginx
```

**Step 2 – Fix the file**

```bash
vi /root/broken-deploy.yaml
```

Update to:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: web
          image: nginx
```

**Step 3 – Apply and verify**

```bash
kubectl apply -f /root/broken-deploy.yaml
kubectl get deploy broken-app
kubectl rollout status deploy broken-app
kubectl get pods -l app=myapp
```

**Why this works**

- `apps/v1` is the current stable API version for Deployments
- `apps/v1` requires `spec.selector` field
- `spec.selector.matchLabels` must match `spec.template.metadata.labels`
- Once fixed, the Deployment can manage Pods correctly

**Docs**

- Deployments: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

---

<a id="question-9"></a>
## Question 9 – Perform Rolling Update and Rollback

In namespace `default`, Deployment `app-v1` exists with image `nginx:1.20`.

Your task:
1. Update the Deployment to use image `nginx:1.25`
2. Verify the rolling update completes successfully
3. Rollback to the previous revision
4. Verify the rollback completed

### Solution

**Step 1 – Update the image**

```bash
kubectl set image deploy/app-v1 web=nginx:1.25 -n default
```

Or use edit:

```bash
kubectl edit deploy app-v1 -n default
# Change image to nginx:1.25
```

**Step 2 – Monitor the rollout**

```bash
kubectl rollout status deploy app-v1 -n default
kubectl get pods -n default -l app=app-v1 -w
```

**Step 3 – View rollout history**

```bash
kubectl rollout history deploy app-v1 -n default
```

**Step 4 – Rollback to previous revision**

```bash
kubectl rollout undo deploy app-v1 -n default
```

Or rollback to specific revision:

```bash
kubectl rollout undo deploy app-v1 --to-revision=1 -n default
```

**Step 5 – Verify rollback**

```bash
kubectl rollout status deploy app-v1 -n default
kubectl get deploy app-v1 -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should show nginx:1.20
```

**Why this works**

- `kubectl set image` triggers a rolling update
- Kubernetes maintains revision history for rollbacks
- `kubectl rollout undo` reverts to the previous revision
- Rolling updates ensure zero-downtime deployments

**Docs**

- Rolling Updates: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment

---

<a id="question-10"></a>
## Question 10 – Add Readiness Probe to Deployment

In namespace `default`, Deployment `api-deploy` exists with a container listening on port `8080`.

Your task:
Add a readiness probe to the Deployment with:
- HTTP GET on path `/ready`
- Port `8080`
- `initialDelaySeconds: 5`
- `periodSeconds: 10`

Ensure the Deployment rolls out successfully.

### Solution

**Step 1 – Edit the Deployment**

```bash
kubectl edit deploy api-deploy -n default
```

Add under the container spec:

```yaml
spec:
  template:
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

Save and exit.

**Step 2 – Verify rollout**

```bash
kubectl rollout status deploy api-deploy -n default
kubectl describe deploy api-deploy -n default
```

**Step 3 – Check probe status**

```bash
kubectl get pods -n default -l app=api-deploy
kubectl describe pod <pod-name> -n default
# Look for Readiness in Conditions section
```

**Why this works**

- Readiness probes determine when a Pod is ready to receive traffic
- Pods that fail readiness checks are removed from Service endpoints
- `initialDelaySeconds` gives the container time to start
- `periodSeconds` sets how often the probe runs

**Docs**

- Readiness Probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

---

<a id="question-11"></a>
## Question 11 – Configure Pod and Container Security Context

In namespace `default`, Deployment `secure-app` exists without any security context.

Your task:
1. Set Pod-level `runAsUser: 1000`
2. Add container-level capability `NET_ADMIN` to the container named `app`

**Note:** Capabilities are set at the container level, not the Pod level.

### Solution

**Step 1 – Edit the Deployment**

```bash
kubectl edit deploy secure-app -n default
```

Add security context at Pod level and container level:

```yaml
spec:
  template:
    spec:
      securityContext:  # Pod-level
        runAsUser: 1000
      containers:
        - name: app
          image: nginx
          securityContext:  # Container-level
            capabilities:
              add:
                - NET_ADMIN
```

Save and exit.

**Step 2 – Verify rollout**

```bash
kubectl rollout status deploy secure-app -n default
```

**Step 3 – Verify security context**

```bash
kubectl get pod -n default -l app=secure-app -o yaml | grep -A 10 securityContext
```

Or describe a pod:

```bash
kubectl describe pod <pod-name> -n default
```

**Why this works**

- Pod-level `securityContext.runAsUser` sets the user ID for all containers
- Container-level `securityContext.capabilities.add` adds Linux capabilities
- `NET_ADMIN` capability allows network configuration operations
- Security contexts enhance Pod security and functionality

**Docs**

- Security Context: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

<a id="question-12"></a>
## Question 12 – Fix Service Selector

In namespace `default`, Deployment `web-app` exists with Pods labeled `app=webapp, tier=frontend`.

Service `web-svc` exists but has incorrect selector `app=wrongapp`.

Your task:
Update Service `web-svc` to correctly select Pods from Deployment `web-app`.

### Solution

**Step 1 – Check current state**

```bash
kubectl get pods -n default --show-labels
kubectl get svc web-svc -n default -o yaml
kubectl get endpoints web-svc -n default  # Should be empty or wrong
```

**Step 2 – Update Service selector**

```bash
kubectl edit svc web-svc -n default
```

Change:

```yaml
spec:
  selector:
    app: wrongapp
```

To:

```yaml
spec:
  selector:
    app: webapp
```

Save and exit.

**Step 3 – Verify endpoints**

```bash
kubectl get endpoints web-svc -n default
# Should now show IPs of web-app pods
kubectl describe svc web-svc -n default
```

**Why this works**

- Service selectors must match Pod labels to create endpoints
- When selector matches, Kubernetes automatically creates Endpoints
- Fixed selector allows traffic to reach the correct Pods

**Docs**

- Services: https://kubernetes.io/docs/concepts/services-networking/service/

---

<a id="question-13"></a>
## Question 13 – Create NodePort Service

In namespace `default`, Deployment `api-server` exists with Pods labeled `app=api` and container port `9090`.

Your task:
Create a Service named `api-nodeport` that:
- Type: `NodePort`
- Selects Pods with label `app=api`
- Exposes Service port `80` mapping to target port `9090`

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: api-nodeport
  namespace: default
spec:
  type: NodePort
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 9090
      protocol: TCP
EOF
```

Verify:

```bash
kubectl get svc api-nodeport -n default
kubectl describe svc api-nodeport -n default
# Note the NodePort port (e.g., 30080)
```

**Why this works**

- `NodePort` Service type exposes the service on a port on each node
- Kubernetes assigns a port in the 30000-32767 range automatically
- External traffic can access the service via `<node-ip>:<node-port>`
- Service port 80 maps to container port 9090

**Docs**

- NodePort Services: https://kubernetes.io/docs/concepts/services-networking/service/#nodeport

---

<a id="question-14"></a>
## Question 14 – Create Ingress Resource

In namespace `default`, the following resources exist:
- Deployment `web-deploy` with Pods labeled `app=web`
- Service `web-svc` with selector `app=web` on port `8080`

Your task:
Create an Ingress named `web-ingress` that:
- Routes host `web.example.com`
- Path `/` with `pathType: Prefix`
- Backend Service `web-svc` on port `8080`
- Uses API version `networking.k8s.io/v1`

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: default
spec:
  rules:
    - host: web.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 8080
EOF
```

Verify:

```bash
kubectl get ingress web-ingress -n default
kubectl describe ingress web-ingress -n default
```

**Why this works**

- `networking.k8s.io/v1` is the stable Ingress API version
- `pathType: Prefix` matches paths starting with `/`
- Ingress routes external traffic to internal Services
- Host-based routing allows multiple services behind one IP

**Docs**

- Ingress: https://kubernetes.io/docs/concepts/services-networking/ingress/

---

<a id="question-15"></a>
## Question 15 – Fix Ingress PathType

File `/root/fix-ingress.yaml` contains an Ingress manifest that fails to apply due to an invalid `pathType` value.

Your task:
1. Apply the file and note the error
2. Fix the `pathType` to a valid value (`Prefix`, `Exact`, or `ImplementationSpecific`)
3. Ensure the Ingress routes path `/api` to Service `api-svc` on port `8080`
4. Apply the fixed manifest successfully

### Solution

**Step 1 – Try to apply (will fail)**

```bash
kubectl apply -f /root/fix-ingress.yaml
# Error: pathType: Unsupported value: "InvalidType"
```

**Step 2 – View and fix the file**

```bash
cat /root/fix-ingress.yaml
vi /root/fix-ingress.yaml
```

Change the invalid `pathType` (e.g., `InvalidType`) to a valid value:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix  # Changed from InvalidType
            backend:
              service:
                name: api-svc
                port:
                  number: 8080
```

**Step 3 – Apply the fixed manifest**

```bash
kubectl apply -f /root/fix-ingress.yaml
kubectl get ingress api-ingress -n default
```

**Why this works**

- Ingress v1 API only accepts `Prefix`, `Exact`, or `ImplementationSpecific` as pathType
- `Prefix` is the most commonly used value
- Once fixed, the Ingress resource is accepted by the API server

**Docs**

- Ingress Path Types: https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types

---

<a id="question-16"></a>
## Question 16 – Add Resource Requests and Limits to Pod

In namespace `prod`, create a Pod named `resource-pod` with:
- Image: `nginx:latest`
- CPU request: `100m`
- CPU limit: `500m`
- Memory request: `128Mi`
- Memory limit: `256Mi`

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
  namespace: prod
spec:
  containers:
    - name: web
      image: nginx:latest
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
EOF
```

Verify:

```bash
kubectl get pod resource-pod -n prod -o yaml | grep -A 10 resources
kubectl describe pod resource-pod -n prod
```

**Why this works**

- Resource requests help Kubernetes schedule Pods to nodes with available resources
- Resource limits prevent a Pod from consuming excessive resources
- CPU in millicores (1000m = 1 core)
- Memory in binary (Mi, Gi) or decimal (M, G) units

**Docs**

- Resource Management: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

---

## Summary

This practice exam covers the core CKAD topics you'll encounter:

- **Secrets and ConfigMaps** - Externalizing configuration
- **CronJobs** - Scheduled jobs with history limits
- **RBAC** - ServiceAccounts, Roles, RoleBindings
- **Container Images** - Building and managing images
- **Deployments** - Updates, rollbacks, probes, security contexts
- **Services** - ClusterIP, NodePort, selectors
- **Ingress** - Routing external traffic
- **Network Policies** - Controlling traffic flow

**Key Tips for the Exam:**
- Use `kubectl explain <resource>.<field>` extensively
- Check pod logs for error hints
- Use `kubectl label` for quick label fixes
- Export YAML, edit, and reapply for complex changes
- Verify changes with `kubectl get`, `kubectl describe`, and `kubectl logs`
- Practice time management - flag difficult questions and move on

Good luck with your CKAD exam!

