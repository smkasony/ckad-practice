#!/bin/bash
set -euo pipefail

image_ref="my-app:1.0"
tar_path="/root/my-app.tar"

have_podman=false
have_docker=false

if command -v podman >/dev/null 2>&1; then
  have_podman=true
fi

if command -v docker >/dev/null 2>&1; then
  have_docker=true
fi

if [[ "$have_podman" != "true" && "$have_docker" != "true" ]]; then
  echo "Neither podman nor docker is available to verify the task" >&2
  exit 1
fi

# Check image exists (accept either engine)
image_found=false

if [[ "$have_podman" == "true" ]]; then
  if podman images --format '{{.Repository}}:{{.Tag}}' | grep -qx "$image_ref"; then
    image_found=true
  fi
fi

if [[ "$image_found" != "true" && "$have_docker" == "true" ]]; then
  if docker images --format '{{.Repository}}:{{.Tag}}' | grep -qx "$image_ref"; then
    image_found=true
  fi
fi

if [[ "$image_found" != "true" ]]; then
  echo "Image $image_ref not found (checked podman and docker)" >&2
  exit 1
fi

# Check tarball exists and looks like an image archive
if [[ ! -f "$tar_path" ]]; then
  echo "Tarball $tar_path not found" >&2
  exit 1
fi

if [[ ! -s "$tar_path" ]]; then
  echo "Tarball $tar_path is empty" >&2
  exit 1
fi

# Most image archives contain manifest.json (docker save / podman save)
if ! tar -tf "$tar_path" | grep -Eq '(^|/)manifest\.json$|(^|/)index\.json$'; then
  echo "Tarball $tar_path does not look like a container image archive" >&2
  exit 1
fi
