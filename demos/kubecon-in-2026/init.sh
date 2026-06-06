#!/usr/bin/env bash
set -euo pipefail
# init.sh — Bootstrap a local cluster with KubeVela + Crossplane for THIS demo.
#
# Per-demo bootstrap: run from the demo directory. After it succeeds the cluster
# has the KubeVela control plane and a cloud-resource orchestrator (Crossplane by
# default; swappable with ACK/KCC) ready for the platform building blocks that
# setup.sh installs.

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"
# shellcheck source=../../scripts/setup-venv.sh
source "$REPO_ROOT/scripts/setup-venv.sh"

print_step "KubeVela: One Interface — environment bootstrap"

print_step "Phase 0: Prerequisites"
# python3 (3.12) is used to create the demo .venv and run the sample apps.
require_tools python3 kubectl helm vela docker k3d || {
    print_error "Install missing tools first:"
    echo "  brew install python@3.12 k3d kubectl helm docker"
    echo "  curl -fsSl https://kubevela.io/script/install.sh | bash"
    exit 1
}

# Python virtual environment — demo-local (created in this demo's folder, not
# shared) and activated. Tooling deps (PyYAML, used by scripts/load_config.py to
# parse config.yaml) install from the shared scripts/requirements.txt.
setup_venv "$DEMO_DIR/.venv" "$REPO_ROOT/scripts/requirements.txt"

# Load this demo's configuration. Exports CLUSTER_NAME, API_PORT, HTTP_PORT,
# CROSSPLANE_NAMESPACE, MIN_CRDS, and SETUP_DIR. Requires PyYAML from the venv above.
# shellcheck source=../../scripts/load-config.sh
source "$REPO_ROOT/scripts/load-config.sh"
load_config "$DEMO_DIR/config.yaml"

# shellcheck source=../../scripts/create-cluster.sh
source "$REPO_ROOT/scripts/create-cluster.sh"
# shellcheck source=../../scripts/load-aws-env.sh
source "$REPO_ROOT/scripts/load-aws-env.sh"
# shellcheck source=../../scripts/install-crossplane.sh
source "$REPO_ROOT/scripts/install-crossplane.sh"
# shellcheck source=../../scripts/create-aws-secret.sh
source "$REPO_ROOT/scripts/create-aws-secret.sh"
# shellcheck source=../../scripts/apply-crossplane-function.sh
source "$REPO_ROOT/scripts/apply-crossplane-function.sh"
# shellcheck source=../../scripts/apply-crossplane-provider.sh
source "$REPO_ROOT/scripts/apply-crossplane-provider.sh"
# shellcheck source=../../scripts/apply-crossplane-provider-config.sh
source "$REPO_ROOT/scripts/apply-crossplane-provider-config.sh"
# shellcheck source=../../scripts/install-kubevela.sh
source "$REPO_ROOT/scripts/install-kubevela.sh"

print_step "Phase 1: Create local cluster (k3d + local registry)"
# Uses CLUSTER_NAME / API_PORT / HTTP_PORT exported by load_config above.
create_cluster

print_step "Phase 2: Establishing connectivity to the cloud provider"
# Load AWS credentials from this demo's .env.aws (demo-local). No --skip: if the
# file is missing, a template is written and the bootstrap stops so credentials
# can be filled in before provisioning real cloud resources.
AWS_ENV_FILE="$DEMO_DIR/.env.aws"
load_aws_env "$AWS_ENV_FILE"

print_step "Phase 3: Install cloud-resource orchestrator (Crossplane)"
# Uses CROSSPLANE_NAMESPACE / MIN_CRDS exported by load_config above.
install_crossplane
# Sub-step: wait for Crossplane CRDs to register before anything uses them.
wait_for_crossplane_crds
# Sub-step: Crossplane packages + provider wiring, in dependency order —
#   1) the aws-credentials secret (from .env.aws creds loaded in Phase 2),
#   2) the function(s) used by Composition pipelines (function-patch-and-transform),
#   3) the provider packages (aws-s3 + kubernetes; register their CRDs),
#   4) the ProviderConfigs (need the provider CRDs above, and aws needs the secret).
create_aws_secret "$CROSSPLANE_NAMESPACE" aws-credentials
apply_crossplane_function "$REPO_ROOT/platform/crossplane/function"
apply_crossplane_provider "$REPO_ROOT/platform/crossplane/provider"
apply_crossplane_provider_config "$REPO_ROOT/platform/crossplane/provider-config"
# The S3 XRD + Composition (platform/crossplane/s3/) are applied by setup.sh Phase 1.

print_step "Phase 4: Install KubeVela control plane"
# --velaux also enables the VelaUX addon and port-forwards it to :8000.
# Drop the flag to install the control plane only.
install_kubevela --velaux

print_success "Bootstrap scaffold complete. Fill in the TODOs, then run ./setup.sh"
