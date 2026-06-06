#!/usr/bin/env bash
set -euo pipefail
# build-image.sh — Build the Product Catalog API image and push it to the local
# k3d registry. Self-contained (run from anywhere); builds from this folder's
# Dockerfile.
#
# Usage:
#   ./build-image.sh [image_name] [tag] [host_registry] [incluster_registry]
#
# Defaults match this repo's local k3d setup (see scripts/create-cluster.sh):
#   image_name          product-catalog
#   tag                 v1.0.0
#   host_registry       localhost:5000              (where `docker push` sends it)
#   incluster_registry  k3d-registry.localhost:5000 (how pods pull it; use this in
#                                                     the KubeVela Application image)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_NAME="${1:-product-catalog}"
TAG="${2:-v1.0.0}"
HOST_REGISTRY="${3:-localhost:5000}"
INCLUSTER_REGISTRY="${4:-k3d-registry.localhost:5000}"

IMAGE="${IMAGE_NAME}:${TAG}"
HOST_REF="${HOST_REGISTRY}/${IMAGE}"
INCLUSTER_REF="${INCLUSTER_REGISTRY}/${IMAGE}"

if ! command -v docker >/dev/null 2>&1; then
    echo "✗ docker is required but not installed" >&2
    exit 1
fi

echo "=== Building ${IMAGE} ==="
# Legacy builder (DOCKER_BUILDKIT=0) pushes cleanly to the plain-HTTP k3d registry.
DOCKER_BUILDKIT=0 docker build -t "$IMAGE" "$SCRIPT_DIR"

echo "Tagging for local registry: ${HOST_REF}"
docker tag "$IMAGE" "$HOST_REF"

echo "Pushing ${HOST_REF} ..."
docker push "$HOST_REF"

echo ""
echo "✓ Image built and pushed: ${HOST_REF}"
echo "  Use this image reference in the KubeVela Application:"
echo "      ${INCLUSTER_REF}"
