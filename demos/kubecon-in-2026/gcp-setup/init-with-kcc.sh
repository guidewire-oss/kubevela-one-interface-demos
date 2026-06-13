#!/usr/bin/env bash
set -euo pipefail
# init-with-kcc.sh — Track 3 bootstrap: local cluster + Google Config Connector
# (KCC) as the cloud-resource orchestrator (instead of Crossplane or ACK).
#
# Same Phases 0–2 as init.sh / init-with-ack.sh (prerequisites, cluster, cloud
# connectivity), but Phase 3 installs the Config Connector operator + a
# cluster-mode ConfigConnector via scripts/install-kcc.sh rather than Crossplane
# or ACK. The developer-facing `bucket` claim is identical across all three
# tracks; only this platform-side orchestrator changes.
#
# This script lives in gcp-setup/ (one level below the demo dir). All of its
# own state — config.yaml, .env.gcp, gcp-key.json, the generated .env.sh, and
# the .venv — is kept HERE in gcp-setup/ (resolved via SCRIPT_DIR), so the KCC
# track is self-contained and never reaches up into the parent demo dir. Only
# the shared, reusable scripts under REPO_ROOT/scripts/ are sourced from above.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"
# shellcheck source=../../../scripts/setup-venv.sh
source "$REPO_ROOT/scripts/setup-venv.sh"

print_step "KubeVela: One Interface — environment bootstrap (KCC track)"

print_step "Phase 0: Prerequisites"
# python3 (3.12) creates the demo .venv and runs the sample apps. curl + tar are
# used by install-kcc.sh to fetch and unpack the Config Connector operator bundle.
require_tools python3 kubectl helm vela docker k3d curl tar || {
    print_error "Install missing tools first:"
    echo "  brew install python@3.12 k3d kubectl helm docker"
    echo "  curl -fsSl https://kubevela.io/script/install.sh | bash"
    exit 1
}

# Python virtual environment — local to gcp-setup/ (created here, not shared)
# and activated. Tooling deps (PyYAML, used by scripts/load_config.py to parse
# config.yaml) install from scripts/requirements.txt.
setup_venv "$SCRIPT_DIR/.venv" "$REPO_ROOT/scripts/requirements.txt"

# Load this setup folder's configuration. Exports CLUSTER_NAME, API_PORT,
# HTTP_PORT, CROSSPLANE_NAMESPACE, MIN_CRDS, and SETUP_DIR (and writes .env.sh
# next to config.yaml, i.e. into gcp-setup/). Requires PyYAML from the venv above.
# shellcheck source=../../../scripts/load-config.sh
source "$REPO_ROOT/scripts/load-config.sh"
load_config "$SCRIPT_DIR/config.yaml"

# shellcheck source=../../../scripts/create-cluster.sh
source "$REPO_ROOT/scripts/create-cluster.sh"
# shellcheck source=../../../scripts/load-gcp-env.sh
source "$REPO_ROOT/scripts/load-gcp-env.sh"
# shellcheck source=../../../scripts/create-gcp-secret.sh
source "$REPO_ROOT/scripts/create-gcp-secret.sh"
# shellcheck source=../../../scripts/install-kcc.sh
source "$REPO_ROOT/scripts/install-kcc.sh"
# shellcheck source=../../../scripts/install-kubevela.sh
source "$REPO_ROOT/scripts/install-kubevela.sh"

print_step "Phase 1: Create local cluster (k3d + local registry)"
# Uses CLUSTER_NAME / API_PORT / HTTP_PORT exported by load_config above.
create_cluster

print_step "Phase 2: Establishing connectivity to the cloud provider"
# Load GCP credentials from gcp-setup/.env.gcp. No --skip: if the file is
# missing, a template is written here and the bootstrap stops so credentials
# (project id + service-account key path) can be filled in before provisioning.
GCP_ENV_FILE="$SCRIPT_DIR/.env.gcp"
load_gcp_env "$GCP_ENV_FILE"

print_step "Phase 3: Install cloud-resource orchestrator (Config Connector)"
# Apply the Config Connector operator bundle, then the cluster-mode ConfigConnector
# from the versioned platform asset (platform/kcc/config-connector/configconnector.yaml)
# wired to the GCP service-account key loaded in Phase 2. install_kcc creates the
# gcp-key secret (data key key.json) in cnrm-system via create_gcp_secret and
# waits for cnrm-controller-manager to come up.
KCC_CC_MANIFEST="$REPO_ROOT/platform/kcc/config-connector/configconnector.yaml"
install_kcc gcp-key latest "$KCC_CC_MANIFEST"

print_step "Phase 4: Install KubeVela control plane"
# --velaux also enables the VelaUX addon and port-forwards it to :8000.
# Drop the flag to install the control plane only.
install_kubevela --velaux

print_success "KCC track bootstrap complete: cluster up, Config Connector + KubeVela installed."
