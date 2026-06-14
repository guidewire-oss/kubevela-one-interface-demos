#!/usr/bin/env bash
set -euo pipefail
# setup.sh — Install platform building blocks and deploy the sample app for THIS demo.
#
# Run AFTER ./init.sh has bootstrapped the cluster. This applies the
# platform-team building blocks (the How) and then deploys a developer-facing
# Application (the What) to prove the one-interface model end to end.
#
# STATUS: Phase 1 (apply S3 definition+composition + bucket component), Phase 2a
# (build image), Phase 2b (AWS creds in app namespaces) and Phase 2c (deploy the
# product-catalog Application) are all wired. Phase 3 (verify) is still a stub.

# This script lives in aws-setup/. Its own state (.env.aws) is resolved via
# SCRIPT_DIR; the SHARED Application (kubevela/product-catalog.yaml) lives in the
# parent demo dir, so DEMO_DIR points there; REPO_ROOT is three levels up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"
# shellcheck source=../../../scripts/load-aws-env.sh
source "$REPO_ROOT/scripts/load-aws-env.sh"
# shellcheck source=../../../scripts/create-aws-secret.sh
source "$REPO_ROOT/scripts/create-aws-secret.sh"

print_step "KubeVela: One Interface — platform + app setup"

print_step "Phase 1: Apply platform building blocks (the How)"
# Crossplane S3 backend — apply the composite definition (XRD) first, then the
# composition that implements it. Order matters (the composition references the
# definition's composite type), so apply the files individually, not the dir.
print_warning "Applying Crossplane S3 definition + composition..."
kubectl apply -f "$REPO_ROOT/platform/crossplane/s3/definition.yaml"
kubectl apply -f "$REPO_ROOT/platform/crossplane/s3/composition.yaml"
print_success "S3 definition + composition applied"
# (function-patch-and-transform, which the composition pipeline uses, is installed
# by init.sh Phase 3.)

# Apply the developer-facing `bucket` ComponentDefinition (CUE) so an Application
# can claim an S3 bucket. The XRD + Composition above are what it resolves to.
print_warning "Applying the 'bucket' ComponentDefinition (vela def apply)..."
vela def apply "$REPO_ROOT/platform/kubevela/components/bucket-xp.cue"
print_success "'bucket' ComponentDefinition installed"
# TODO: apply the other X-Definitions as the demo Application needs them
#   (high-availability trait, and — for the direct approach — s3-bucket + s3-versioning).

print_step "Phase 2: Build + deploy the application (the What)"

# 2a — Build app image(s) and push to the local k3d registry (created by init.sh).
#      Build lives here, next to the deploy that consumes it, so the edit→rebuild→
#      redeploy loop never needs to re-run init.sh.
print_step "Phase 2a: Build application image"
bash "$REPO_ROOT/apps/product-catalog/build-image.sh"
# The bucket-browser web UI is a second component in the Application — build it too.
bash "$REPO_ROOT/apps/bucket-browser/build-image.sh"

# 2b — AWS credentials in the app namespaces (dev/staging/prod). App pods mount this
#      secret to reach S3. setup.sh is a separate process from init.sh, so load
#      .env.aws here to get AWS_* into the environment; then create the secret per
#      namespace (creating the namespace if it doesn't exist).
print_step "Phase 2b: Set up AWS credentials in app namespaces"
load_aws_env "$SCRIPT_DIR/.env.aws"
for ns in dev staging prod; do
    create_aws_secret --create-namespace "$ns" aws-credentials
done

# 2c — Deploy this demo's KubeVela Application(s).
print_step "Phase 2c: Deploy the application"
# Submit the Application. Its multi-env workflow auto-deploys to dev (and runs the
# functional API tests), then SUSPENDS for manual approval before staging and prod —
# so this returns once dev is rolling. Resume later with:
#   vela workflow resume product-catalog
vela up -f "$DEMO_DIR/kubevela/product-catalog.yaml"
print_success "Application submitted (workflow deploys dev, then suspends for approval)"

print_step "Phase 3: Verify"
print_warning "TODO: check app status and exercise the running service"
# vela status <app>
# kubectl get pods,hpa,pdb -A

print_success "Setup scaffold complete. See ./README.md and ./walkthrough.md for the walkthrough."
