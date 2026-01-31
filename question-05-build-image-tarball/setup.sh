#!/bin/bash
set -euo pipefail

# Ensure build context exists
mkdir -p /root/app-source

cat > /root/app-source/Dockerfile <<'EOF'
FROM busybox:1.36
CMD ["sh", "-c", "echo Build OK; sleep 3600"]
EOF

# Remove any previous artifacts
rm -f /root/my-app.tar

# Best-effort: ensure a container build tool exists.
# Killercoda "ubuntu" images usually allow apt, but this should not break if it's unavailable.
if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    # Install podman if possible
    apt-get install -y podman >/dev/null || true
  fi
fi
