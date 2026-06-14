#!/usr/bin/env bash
set -euo pipefail
# setup-with-ack.sh — Track 2 platform setup: install the ACK backing of the
# `bucket` claim for THIS demo.
#
# Run AFTER ./init-with-ack.sh has bootstrapped the cluster (ACK S3 controller +
# KubeVela). The Track-1 setup.sh applies an XRD + Composition before the `bucket`
# component; ACK has no composition layer, so Phase 1 here is just the one
# `vela def apply` of bucket-ack.cue. The developer Application is identical across
# tracks — only this platform-side definition changes.
#
# STATUS: Phase 1 (apply bucket-ack.cue), Phase 2a (build image), Phase 2b (AWS creds
# in app namespaces) and Phase 2c (deploy the product-catalog Application) are wired.
# Phase 3 (verify) is still a stub — mirrors setup.sh.

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

print_step "KubeVela: One Interface — platform setup (ACK track)"

print_step "Phase 1: Apply platform building blocks (the How)"
# Apply the ACK backing of the developer-facing `bucket` ComponentDefinition. It
# registers a definition ALSO named `bucket`, resolving the same claim to a single
# ACK s3.services.k8s.aws Bucket (no XRD/Composition needed). Apply exactly one of
# bucket-xp.cue / bucket-ack.cue — whichever is installed backs the claim.
print_warning "Applying the 'bucket' ComponentDefinition (ACK backing, vela def apply)..."
vela def apply "$REPO_ROOT/platform/kubevela/components/bucket-ack.cue"
print_success "'bucket' ComponentDefinition (ACK) installed"

print_step "Phase 2: Build + deploy the application (the What)"

# 2a — Build app image(s) and push to the local k3d registry (created by init.sh).
#      Build lives here, next to the deploy that consumes it, so the edit→rebuild→
#      redeploy loop never needs to re-run init.sh. The app is track-agnostic — it
#      talks to S3 via boto3 regardless of who provisioned the bucket.
print_step "Phase 2a: Build application image"
bash "$REPO_ROOT/apps/product-catalog/build-image.sh"
# The bucket-browser web UI is a second component in the Application — build it too.
bash "$REPO_ROOT/apps/bucket-browser/build-image.sh"

# 2b — AWS credentials in the app namespaces (dev/staging/prod). App pods mount this
#      secret to reach S3. This is the APP's runtime creds (boto3) — separate from the
#      ACK controller's creds — so it is needed on the ACK track too. setup is a
#      separate process from init, so load .env.aws here to get AWS_* into the
#      environment; then create the secret per namespace (creating it if absent).
print_step "Phase 2b: Set up AWS credentials in app namespaces"
load_aws_env "$SCRIPT_DIR/.env.aws"
for ns in dev staging prod; do
    create_aws_secret --create-namespace "$ns" aws-credentials
done

# 2c — Deploy this demo's KubeVela Application(s). IDENTICAL Application to the
#      Crossplane track — the `bucket` claim now resolves via ACK because
#      bucket-ack.cue is the installed backing.
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
# kubectl get buckets.s3.services.k8s.aws -A   # the ACK bucket(s) the claim created

print_success "ACK setup scaffold complete: the 'bucket' claim now resolves via ACK. See ./README.md and ./walkthrough.md."
