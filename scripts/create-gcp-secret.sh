#!/usr/bin/env bash
# Create the `gcp-key` secret Config Connector (KCC) uses to authenticate to GCP.
#
# Expects GOOGLE_APPLICATION_CREDENTIALS in the environment, pointing at a
# service-account JSON key file — load_gcp_env (Phase 2) exports it from .env.gcp.
# The GCP/KCC analogue of create-aws-secret.sh.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# create_gcp_secret [--create-namespace] [namespace] [secret_name]
# Reads the service-account JSON key at GOOGLE_APPLICATION_CREDENTIALS and applies
# it as a generic secret under the data key `key.json` (the name KCC's controller
# reads — it mounts the secret at /var/secrets/google/key.json).
#
# Namespace handling (same contract as create_aws_secret):
#   --create-namespace given → create the namespace if it doesn't exist.
#   not given + namespace missing → error out (return 1).
#   namespace already exists → used as-is either way.
#
# Defaults: namespace ${KCC_NAMESPACE:-cnrm-system}, secret_name `gcp-key`
# (matches KCC's spec.credentialSecretName convention for cluster mode).
create_gcp_secret() {
    local create_ns=false
    local positional=()
    local arg
    for arg in "$@"; do
        case "$arg" in
            --create-namespace|--create-ns) create_ns=true ;;
            *)                               positional+=("$arg") ;;
        esac
    done
    local namespace="${positional[0]:-${KCC_NAMESPACE:-cnrm-system}}"
    local secret_name="${positional[1]:-gcp-key}"

    if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
        print_error "GCP credentials not set (GOOGLE_APPLICATION_CREDENTIALS) — did Phase 2 load .env.gcp?"
        return 1
    fi
    if [ ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
        print_error "Service-account key file not found: ${GOOGLE_APPLICATION_CREDENTIALS}"
        return 1
    fi

    # Ensure the namespace exists; create it only when asked.
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        if [ "$create_ns" = true ]; then
            print_warning "Namespace '$namespace' not found — creating it"
            kubectl create namespace "$namespace"
        else
            print_error "Namespace '$namespace' does not exist (pass --create-namespace to create it)"
            return 1
        fi
    fi

    print_step "Creating '$secret_name' secret in namespace '$namespace'"
    print_warning "Using service-account key: ${GOOGLE_APPLICATION_CREDENTIALS}"

    kubectl create secret generic "$secret_name" \
        -n "$namespace" \
        --from-file=key.json="${GOOGLE_APPLICATION_CREDENTIALS}" \
        --dry-run=client -o yaml | kubectl apply -f -

    print_success "GCP credentials secret created"
}
