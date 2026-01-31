#!/bin/bash
set -euo pipefail

cluster_ok=false
for i in {1..60}; do
  if kubectl get nodes >/dev/null 2>&1; then
    cluster_ok=true
    break
  fi
  sleep 2
done

if [[ "$cluster_ok" != "true" ]]; then
  echo "Kubernetes cluster not reachable (expected in Killercoda)." >&2
  exit 1
fi

kubectl delete ingress api-ingress -n default --ignore-not-found
kubectl delete svc api-svc -n default --ignore-not-found

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: default
spec:
  selector:
    app: api
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
YAML

# Provide a manifest on disk that fails validation until the user fixes it.
cat > /root/fix-ingress.yaml <<'YAML'
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
            pathType: InvalidType
            backend:
              service:
                name: api-svc
                port:
                  number: 8080
YAML
