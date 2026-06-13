#!/usr/bin/env bash
set -euo pipefail
# setup-with-kcc.sh — Track 3 platform setup: install the KCC backing of the
# `bucket` claim for THIS demo.
#
# Run AFTER ./init-with-kcc.sh has bootstrapped the cluster (Config Connector +
# KubeVela). Like the ACK track (and unlike Crossplane, which applies an XRD +
# Composition first), KCC has no composition layer — so Phase 1 here is just the
# one `vela def apply` of bucket-kcc.cue. The developer Application is identical
# across all three tracks; only this platform-side definition changes.
#
# This script lives in gcp-setup/ (one level below the demo dir); REPO_ROOT is
# resolved three levels up, the same as init-with-kcc.sh.
#
# STATUS: Phase 1 (apply bucket-kcc.cue) only. The app build/deploy and verify
# phases (mirroring setup-with-ack.sh Phases 2–3) are intentionally not wired yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"

print_step "KubeVela: One Interface — platform setup (KCC track)"

print_step "Phase 1: Apply platform building blocks (the How)"
# Apply the KCC backing of the developer-facing `bucket` ComponentDefinition. It
# registers a definition ALSO named `bucket`, resolving the same claim to a single
# storage.cnrm.cloud.google.com StorageBucket (no XRD/Composition needed). Apply
# exactly one of bucket.cue / bucket-ack.cue / bucket-kcc.cue — whichever is
# installed backs the claim.
print_warning "Applying the 'bucket' ComponentDefinition (KCC backing, vela def apply)..."
vela def apply "$REPO_ROOT/platform/kubevela/components/bucket-kcc.cue"
print_success "'bucket' ComponentDefinition (KCC) installed"

print_success "KCC setup (Phase 1) complete: the 'bucket' claim now resolves via KCC into a GCS bucket."
