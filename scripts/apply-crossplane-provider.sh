#!/usr/bin/env bash
# Apply the Crossplane AWS provider package and wait for it to be installed +
# healthy (which registers the aws.upbound.io ProviderConfig CRD).
#
# Manifests live in platform/crossplane/provider/. Apply the ProviderConfig
# separately AFTER this (see apply-crossplane-provider-config.sh).
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# apply_crossplane_provider <provider_dir>
# Applies every manifest in provider_dir, then waits for all Crossplane providers
# to become installed and healthy.
apply_crossplane_provider() {
    local provider_dir="$1"

    if [ -z "$provider_dir" ]; then
        print_error "usage: apply_crossplane_provider <provider_dir>"
        return 1
    fi
    if [ ! -d "$provider_dir" ]; then
        print_error "provider directory not found: $provider_dir"
        return 1
    fi

    print_step "Installing Crossplane AWS provider"
    kubectl apply -f "$provider_dir"

    print_warning "Waiting for provider(s) to be installed..."
    kubectl wait --for=condition=installed --timeout=300s providers.pkg.crossplane.io --all
    print_warning "Waiting for provider(s) to be healthy..."
    kubectl wait --for=condition=healthy --timeout=300s providers.pkg.crossplane.io --all
    print_success "Provider installed and healthy"
}
