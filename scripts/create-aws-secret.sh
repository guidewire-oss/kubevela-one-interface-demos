#!/usr/bin/env bash
# Create the `aws-credentials` secret Crossplane uses to authenticate to AWS.
#
# Expects AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (and optionally
# AWS_SESSION_TOKEN) in the environment — load_aws_env (Phase 2) exports them
# from .env.aws.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# create_aws_secret [--create-namespace] [namespace] [secret_name]
# Builds an AWS credentials profile (including the session token when present)
# and applies it as a generic secret in the given namespace.
#
# Namespace handling (so the function is generically reusable):
#   --create-namespace given → create the namespace if it doesn't exist.
#   not given + namespace missing → error out (return 1).
#   namespace already exists → used as-is either way.
create_aws_secret() {
    local create_ns=false
    local positional=()
    local arg
    for arg in "$@"; do
        case "$arg" in
            --create-namespace|--create-ns) create_ns=true ;;
            *)                               positional+=("$arg") ;;
        esac
    done
    local namespace="${positional[0]:-${CROSSPLANE_NAMESPACE:-crossplane-system}}"
    local secret_name="${positional[1]:-aws-credentials}"

    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        print_error "AWS credentials not set (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) — did Phase 2 load .env.aws?"
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

    local creds
    if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
        print_warning "Including session token (temporary credentials)"
        creds="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}"
    else
        print_warning "Using long-term credentials (no session token)"
        creds="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
    fi

    kubectl create secret generic "$secret_name" \
        -n "$namespace" \
        --from-literal=credentials="$creds" \
        --dry-run=client -o yaml | kubectl apply -f -

    print_success "AWS credentials secret created"
}
