#!/usr/bin/env bash
# Install Crossplane via Helm.
#
# A reusable function. Source this file, then call `install_crossplane`. Namespace
# defaults to the CROSSPLANE_NAMESPACE that load_config exports; installs from the
# upstream crossplane-stable chart.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# install_crossplane [namespace] [release_name]
# Adds the Crossplane helm repo, installs (or upgrades if already present), waits
# for the controller pod to be ready, and lists the resulting pods.
install_crossplane() {
    local namespace="${1:-${CROSSPLANE_NAMESPACE:-crossplane-system}}"
    local release="${2:-crossplane}"
    local repo_name="crossplane-stable"
    local repo_url="https://charts.crossplane.io/stable"
    local chart="${repo_name}/crossplane"

    print_step "Installing Crossplane into namespace '$namespace'"

    print_warning "Adding/updating Crossplane helm repository..."
    helm repo add "$repo_name" "$repo_url" 2>/dev/null || echo "Repository already exists"
    helm repo update

    # Install fresh, or upgrade if a release already exists in the namespace.
    local helm_cmd
    if helm list -n "$namespace" 2>/dev/null | grep -q "$release"; then
        print_warning "Crossplane already installed — upgrading..."
        helm_cmd="upgrade"
    else
        print_warning "Installing Crossplane..."
        helm_cmd="install"
    fi

    if helm "$helm_cmd" "$release" "$chart" \
        --namespace "$namespace" \
        --create-namespace \
        --wait \
        --timeout 10m; then
        print_success "Crossplane helm chart $helm_cmd completed"
    else
        print_error "Failed to $helm_cmd Crossplane"
        return 1
    fi

    print_warning "Waiting for Crossplane controller pods to be ready..."
    if kubectl wait --namespace "$namespace" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=cloud-infrastructure-controller \
        --timeout=1200s; then
        print_success "Crossplane controller is ready"
    else
        print_error "Crossplane controller failed to become ready"
        return 1
    fi

    kubectl get pods -n "$namespace"
}

# wait_for_crossplane_crds [min_crds] [namespace]
# Polls until at least <min_crds> Crossplane CRDs are registered. Defaults to the
# MIN_CRDS that load_config exports.
wait_for_crossplane_crds() {
    local min_crds="${1:-${MIN_CRDS:-15}}"
    local namespace="${2:-${CROSSPLANE_NAMESPACE:-crossplane-system}}"
    local max_retries=60
    local retry_delay=5
    local i crd_count

    print_warning "Waiting for at least $min_crds Crossplane CRDs to be installed..."
    for i in $(seq 1 "$max_retries"); do
        crd_count="$(kubectl api-resources 2>/dev/null | grep -c crossplane || true)"
        echo "Attempt $i/$max_retries: found $crd_count Crossplane CRDs"

        if [ "$crd_count" -ge "$min_crds" ]; then
            print_success "Sufficient CRDs available ($crd_count >= $min_crds)"
            break
        fi

        if [ "$i" -eq "$max_retries" ]; then
            print_error "Timeout: only $crd_count CRDs found after $max_retries attempts"
            return 1
        fi

        sleep "$retry_delay"
    done

    echo "Sample Crossplane CRDs:"
    kubectl api-resources 2>/dev/null | grep crossplane | head -10 || true
}
