#!/usr/bin/env bash
set -euo pipefail
# setup-with-kcc.sh — Track 3 platform setup: install the KCC backing of the
# `bucket` claim and deploy the demo app for THIS demo.
#
# Run AFTER ./init-with-kcc.sh has bootstrapped the cluster (Config Connector +
# KubeVela). Like the ACK track (and unlike Crossplane, which applies an XRD +
# Composition first), KCC has no composition layer — so Phase 1 here is just the
# one `vela def apply` of bucket-kcc.cue. The developer `bucket` claim is identical
# across all three tracks; only this platform-side definition changes.
#
# This script lives in gcp-setup/. Its own state (.env.gcp) is resolved via
# SCRIPT_DIR; the SHARED Application lives in the parent demo dir, so DEMO_DIR
# points there; REPO_ROOT is three levels up (same as init-with-kcc.sh).
#
# STATUS: Phases 1, 2a, 2b, 2c wired (mirrors setup-with-ack.sh). Phase 3 (verify)
# is a stub.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"
# shellcheck source=../../../scripts/load-gcp-env.sh
source "$REPO_ROOT/scripts/load-gcp-env.sh"
# shellcheck source=../../../scripts/create-gcp-secret.sh
source "$REPO_ROOT/scripts/create-gcp-secret.sh"

print_step "KubeVela: One Interface — platform setup (KCC track)"

print_step "Phase 1: Apply platform building blocks (the How)"
# Apply the KCC backing of the developer-facing `bucket` ComponentDefinition. It
# registers a definition ALSO named `bucket`, resolving the same claim to a single
# storage.cnrm.cloud.google.com StorageBucket (no XRD/Composition needed). Apply
# exactly one of bucket-xp.cue / bucket-ack.cue / bucket-kcc.cue — whichever is
# installed backs the claim.
print_warning "Applying the 'bucket' ComponentDefinition (KCC backing, vela def apply)..."
vela def apply "$REPO_ROOT/platform/kubevela/components/bucket-kcc.cue"
print_success "'bucket' ComponentDefinition (KCC) installed"

print_step "Phase 2: Build + deploy the application (the What)"

# 2a — Build app image(s) and push to the local k3d registry (created by init.sh).
#      The app is track-agnostic — it talks to GCS via the google-cloud-storage SDK
#      (STORAGE_PROVIDER=gcp) the same way it talks to S3 on the AWS tracks. SAME
#      image; only the runtime env + mounted secret differ (see product-catalog-gcp.yaml).
print_step "Phase 2a: Build application image"
bash "$REPO_ROOT/apps/product-catalog/build-image.sh"
# The bucket-browser web UI is a second component in the Application — build it too.
bash "$REPO_ROOT/apps/bucket-browser/build-image.sh"

# 2b — GCP credentials in the app namespaces (dev/staging/prod). App pods mount this
#      `gcp-key` secret (data key key.json) and point GOOGLE_APPLICATION_CREDENTIALS at
#      it to reach GCS. This is the APP's runtime creds — separate from the KCC
#      controller's gcp-key secret in cnrm-system. setup is a separate process from
#      init, so load .env.gcp here to get GOOGLE_APPLICATION_CREDENTIALS into the
#      environment; then create the secret per namespace (creating it if absent).
print_step "Phase 2b: Set up GCP credentials in app namespaces"
load_gcp_env "$SCRIPT_DIR/.env.gcp"
for ns in dev staging prod; do
    create_gcp_secret --create-namespace "$ns" gcp-key
done

# 2c — Deploy this demo's KubeVela Application. STRUCTURALLY IDENTICAL to the AWS
#      track's product-catalog.yaml — only the cloud-runtime block differs
#      (STORAGE_PROVIDER=gcp + the gcp-key mount); the `bucket` claim is byte-for-byte
#      identical and now resolves via KCC into a GCS bucket.
print_step "Phase 2c: Deploy the application"
# Submit the Application. Its multi-env workflow auto-deploys to dev (and runs the
# functional API tests), then SUSPENDS for manual approval before staging and prod —
# so this returns once dev is rolling. Resume later with:
#   vela workflow resume product-catalog
vela up -f "$DEMO_DIR/kubevela/product-catalog-gcp.yaml"
print_success "Application submitted (workflow deploys dev, then suspends for approval)"

print_step "Phase 3: Verify"
print_warning "TODO: check app status and exercise the running service"
# vela status product-catalog
# kubectl get pods,hpa,pdb -A
# kubectl get storagebucket -A   # the GCS bucket(s) the claim created via KCC

print_success "KCC setup scaffold complete: the 'bucket' claim now resolves via KCC into a GCS bucket. See ./README.md and ./walkthrough.md."
