#!/usr/bin/env bash
# Apply Crossplane Function package(s) and wait for them to be installed + healthy.
# Functions (e.g. function-patch-and-transform) are used by Composition pipelines.
#
# Manifests live in platform/crossplane/function/.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# apply_crossplane_function <function_dir>
# Applies every manifest in function_dir, then waits for all Crossplane functions
# to become installed and healthy.
apply_crossplane_function() {
    local function_dir="$1"

    if [ -z "$function_dir" ]; then
        print_error "usage: apply_crossplane_function <function_dir>"
        return 1
    fi
    if [ ! -d "$function_dir" ]; then
        print_error "function directory not found: $function_dir"
        return 1
    fi

    print_step "Installing Crossplane function(s)"
    kubectl apply -f "$function_dir"

    print_warning "Waiting for function(s) to be installed..."
    kubectl wait --for=condition=installed --timeout=300s functions.pkg.crossplane.io --all
    print_warning "Waiting for function(s) to be healthy..."
    kubectl wait --for=condition=healthy --timeout=300s functions.pkg.crossplane.io --all
    print_success "Function(s) installed and healthy"
}
