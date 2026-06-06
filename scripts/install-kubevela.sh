#!/usr/bin/env bash
# Install the KubeVela control plane (optionally enable + port-forward VelaUX).
#
# Source this file, then call `install_kubevela`. Pass --velaux to also enable the
# VelaUX addon and port-forward it to :8000; without it, only the control plane is
# installed.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# install_kubevela [--velaux]
# Installs KubeVela and waits for vela-core. With --velaux, also enables the
# VelaUX addon and starts a background port-forward to http://localhost:8000.
install_kubevela() {
    local enable_velaux=false
    local arg
    for arg in "$@"; do
        case "$arg" in
            --velaux|velaux) enable_velaux=true ;;
        esac
    done

    print_step "Installing KubeVela control plane"
    vela install

    print_warning "Waiting for KubeVela controller to be ready..."
    if kubectl wait --namespace vela-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=vela-core \
        --timeout=600s; then
        print_success "KubeVela controller is ready"
    else
        print_error "KubeVela controller failed to become ready"
        return 1
    fi

    kubectl get pods -n vela-system
    echo "KubeVela version:"
    kubectl get deployment -n vela-system kubevela-vela-core \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true
    echo ""

    if [ "$enable_velaux" = true ]; then
        print_step "Enabling VelaUX"
        vela addon enable velaux
        print_warning "Starting port-forward for VelaUX..."
        nohup vela port-forward -n vela-system addon-velaux 8000:8000 >/dev/null 2>&1 &
        print_success "VelaUX will be available at http://localhost:8000"
    fi
}
