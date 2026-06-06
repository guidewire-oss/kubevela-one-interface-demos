#!/usr/bin/env bash
set -euo pipefail
# setup.sh — Install platform building blocks and deploy the sample app for THIS demo.
#
# Run AFTER ./init.sh has bootstrapped the cluster. This applies the
# platform-team building blocks (the How) and then deploys a developer-facing
# Application (the What) to prove the one-interface model end to end.
#
# STATUS: partial. The image build (Phase 2a) is wired; applying platform defs
# (Phase 1) and deploying the Application (Phase 2b) are stubs pending the S3
# component/composition + the product-catalog Application.

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"

print_step "KubeVela: One Interface — platform + app setup"

print_step "Phase 1: Apply platform building blocks (the How)"
# Crossplane S3 backend — apply the composite definition (XRD) first, then the
# composition that implements it. Order matters (the composition references the
# definition's composite type), so apply the files individually, not the dir.
print_warning "Applying Crossplane S3 definition + composition..."
kubectl apply -f "$REPO_ROOT/platform/crossplane/s3/definition.yaml"
kubectl apply -f "$REPO_ROOT/platform/crossplane/s3/composition.yaml"
print_success "S3 definition + composition applied"
# NOTE: the composition pipeline uses function-patch-and-transform, which isn't
# installed yet (pending the setup-manifests step) — provisioning won't actually
# run until that lands.
# TODO: vela def apply the high-availability trait + the (pending) bucket component.

print_step "Phase 2: Build + deploy the application (the What)"

# 2a — Build app image(s) and push to the local k3d registry (created by init.sh).
#      Build lives here, next to the deploy that consumes it, so the edit→rebuild→
#      redeploy loop never needs to re-run init.sh.
print_step "Phase 2a: Build application image"
bash "$REPO_ROOT/apps/product-catalog/build-image.sh"

# 2b — Deploy this demo's KubeVela Application(s).
print_step "Phase 2b: Deploy the application"
print_warning "TODO: deploy this demo's KubeVela Application (pending the product-catalog Application)"
# The current kubevela/web-service.yaml is an nginx placeholder; the product-catalog
# Application that uses the image built above is still to be added.
# vela up -f $DEMO_DIR/kubevela/web-service-with-bucket.yaml

print_step "Phase 3: Verify"
print_warning "TODO: check app status and exercise the running service"
# vela status <app>
# kubectl get pods,hpa,pdb -A

print_success "Setup scaffold complete. See ./README.md and ./walkthrough.md for the walkthrough."
