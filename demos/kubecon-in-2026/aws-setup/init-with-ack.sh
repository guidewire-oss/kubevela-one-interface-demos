#!/usr/bin/env bash
set -euo pipefail
# init-with-ack.sh — Track 2 bootstrap: local cluster + ACK as the cloud-resource
# orchestrator (instead of Crossplane).
#
# Same Phases 0–2 as init.sh (prerequisites, cluster, cloud connectivity), but
# Phase 3 installs the ACK controller via scripts/install-ack.sh rather than
# Crossplane. The developer-facing `bucket` claim is identical across both tracks;
# only this platform-side orchestrator changes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"
# shellcheck source=../../../scripts/setup-venv.sh
source "$REPO_ROOT/scripts/setup-venv.sh"

print_step "KubeVela: One Interface — environment bootstrap (ACK track)"

print_step "Phase 0: Prerequisites"
# python3 (3.12) is used to create the demo .venv and run the sample apps.
require_tools python3 kubectl helm vela docker k3d || {
    print_error "Install missing tools first:"
    echo "  brew install python@3.12 k3d kubectl helm docker"
    echo "  curl -fsSl https://kubevela.io/script/install.sh | bash"
    exit 1
}

# Python virtual environment — local to this setup folder (aws-setup/, created
# here via SCRIPT_DIR, not shared) and activated. Tooling deps (PyYAML, used by
# scripts/load_config.py to parse config.yaml) install from scripts/requirements.txt.
setup_venv "$SCRIPT_DIR/.venv" "$REPO_ROOT/scripts/requirements.txt"

# Load this demo's configuration. Exports CLUSTER_NAME, API_PORT, HTTP_PORT,
# CROSSPLANE_NAMESPACE, MIN_CRDS, and SETUP_DIR. Requires PyYAML from the venv above.
# shellcheck source=../../../scripts/load-config.sh
source "$REPO_ROOT/scripts/load-config.sh"
load_config "$SCRIPT_DIR/config.yaml"

# shellcheck source=../../../scripts/create-cluster.sh
source "$REPO_ROOT/scripts/create-cluster.sh"
# shellcheck source=../../../scripts/load-aws-env.sh
source "$REPO_ROOT/scripts/load-aws-env.sh"
# shellcheck source=../../../scripts/create-aws-secret.sh
source "$REPO_ROOT/scripts/create-aws-secret.sh"
# shellcheck source=../../../scripts/install-ack.sh
source "$REPO_ROOT/scripts/install-ack.sh"
# shellcheck source=../../../scripts/install-kubevela.sh
source "$REPO_ROOT/scripts/install-kubevela.sh"

print_step "Phase 1: Create local cluster (k3d + local registry)"
# Uses CLUSTER_NAME / API_PORT / HTTP_PORT exported by load_config above.
create_cluster

print_step "Phase 2: Establishing connectivity to the cloud provider"
# Load AWS credentials from aws-setup/.env.aws (resolved via SCRIPT_DIR). No --skip:
# if the file is missing, a template is written here and the bootstrap stops so
# credentials can be filled in before provisioning real cloud resources.
AWS_ENV_FILE="$SCRIPT_DIR/.env.aws"
load_aws_env "$AWS_ENV_FILE"

print_step "Phase 3: Install cloud-resource orchestrator (ACK)"
# Install the ACK S3 controller from its public-ECR OCI chart, wired to the AWS
# credentials loaded in Phase 2. install_ack_controller creates/refreshes the
# aws-credentials secret in the ACK namespace (via create_aws_secret) and points
# the chart at it (key `credentials`, profile `default`).
install_ack_controller

print_step "Phase 4: Install KubeVela control plane"
# --velaux also enables the VelaUX addon and port-forwards it to :8000.
# Drop the flag to install the control plane only.
install_kubevela --velaux

print_success "ACK track bootstrap complete: cluster up, ACK S3 controller + KubeVela installed."
