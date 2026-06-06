#!/usr/bin/env bash
# Apply the Crossplane AWS ProviderConfig.
#
# Manifests live in platform/crossplane/provider-config/. Run AFTER the provider
# is installed (the aws.upbound.io ProviderConfig CRD is registered by the
# provider) and AFTER the aws-credentials secret exists.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# apply_crossplane_provider_config <provider_config_dir>
# Applies every manifest in provider_config_dir.
apply_crossplane_provider_config() {
    local provider_config_dir="$1"

    if [ -z "$provider_config_dir" ]; then
        print_error "usage: apply_crossplane_provider_config <provider_config_dir>"
        return 1
    fi
    if [ ! -d "$provider_config_dir" ]; then
        print_error "provider-config directory not found: $provider_config_dir"
        return 1
    fi

    print_step "Applying Crossplane ProviderConfig"
    kubectl apply -f "$provider_config_dir"
    print_success "ProviderConfig applied"
}
