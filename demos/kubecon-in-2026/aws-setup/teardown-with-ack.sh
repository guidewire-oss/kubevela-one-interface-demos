#!/usr/bin/env bash
set -euo pipefail
# teardown-with-ack.sh — gracefully tear down the ACK-track Application.
#
# ACK's S3 controller has NO force-destroy (unlike Crossplane's forceDestroy:true and
# KCC's force-destroy annotation), so deleting the Application while a bucket still holds
# objects fails ("...containing objects without force_destroy set to true"). This script
# does what the ACK controller can't: empty the S3 buckets the `bucket` claim created,
# THEN delete the Application, so the controller's DeleteBucket lands on empty buckets.
#
# Run this BEFORE the cluster cleanup (../cleanup.sh). (Crossplane and KCC tracks tear
# down cleanly on their own and need no equivalent.)
#
# This script lives in aws-setup/: SCRIPT_DIR resolves .env.aws; REPO_ROOT is three up.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"
# shellcheck source=../../../scripts/load-aws-env.sh
source "$REPO_ROOT/scripts/load-aws-env.sh"
# shellcheck source=../../../scripts/empty-s3-bucket.sh
source "$REPO_ROOT/scripts/empty-s3-bucket.sh"

APP_NAME="${1:-product-catalog}"

print_step "KubeVela: One Interface — teardown (ACK track)"

# AWS credentials for the aws CLI (so it can empty the buckets).
load_aws_env "$SCRIPT_DIR/.env.aws"

print_step "Phase 1: Empty the S3 buckets the '$APP_NAME' claim created"
# Discover the actual bucket names from the live ACK Bucket CRs (spec.name) across all
# namespaces — no hardcoding, so this matches whatever the Application deployed.
buckets="$(kubectl get buckets.s3.services.k8s.aws -A \
    -o jsonpath='{range .items[*]}{.spec.name}{"\n"}{end}' 2>/dev/null || true)"
if [ -z "${buckets// /}" ]; then
    print_warning "No ACK Bucket resources found — nothing to empty"
else
    for b in $buckets; do
        empty_s3_bucket "$b"
    done
fi

print_step "Phase 2: Delete the Application"
# With the buckets now empty, the ACK controller's DeleteBucket succeeds as the CRs are
# removed. -y skips the confirmation prompt.
vela delete "$APP_NAME" -n default -y

print_success "ACK teardown complete. Run ../cleanup.sh next to delete the cluster + registry."
