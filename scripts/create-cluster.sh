#!/usr/bin/env bash
# Create a k3d cluster wired to a local Docker registry.
#
# A reusable function. Source this file, then call `create_cluster`. It defaults
# to the variables that load_config exports (CLUSTER_NAME / API_PORT / HTTP_PORT)
# but each may be overridden via arguments.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# create_cluster [cluster_name] [api_port] [http_port] [registry_name] [registry_port]
# Recreates the cluster and registry idempotently (deletes any existing ones
# first), points kubectl at the new context, and verifies access.
create_cluster() {
    local cluster_name="${1:-${CLUSTER_NAME:-}}"
    local api_port="${2:-${API_PORT:-6443}}"
    local http_port="${3:-${HTTP_PORT:-8090}}"
    local registry_name="${4:-registry.localhost}"
    local registry_port="${5:-5000}"
    # k3d prefixes managed registries with "k3d-"; that prefixed host is what
    # images are pushed/pulled as from inside the cluster.
    local registry_host="k3d-${registry_name}:${registry_port}"

    if [ -z "$cluster_name" ]; then
        print_error "create_cluster: cluster name not set (pass an argument or export CLUSTER_NAME)"
        return 1
    fi

    print_step "Step 1: Creating k3d cluster '$cluster_name' with local registry"

    # Delete any existing cluster/registry so re-runs are clean.
    print_warning "Cleaning up any existing cluster/registry..."
    k3d cluster delete "$cluster_name" 2>/dev/null || echo "No existing cluster to delete"
    k3d registry delete "$registry_name" 2>/dev/null || echo "No existing registry to delete"

    # Free the registry host port if any container still holds it (e.g. a leftover
    # k3d registry under a different name, or a stray registry container). Without
    # this, `k3d registry create` fails: "Bind for 0.0.0.0:<port> ... port is already
    # allocated". Scoped to whatever docker container publishes the port; names are
    # logged before removal.
    local port_holders
    port_holders="$(docker ps -aq --filter "publish=${registry_port}" 2>/dev/null || true)"
    if [ -n "$port_holders" ]; then
        print_warning "Port ${registry_port} already allocated; removing container(s) holding it:"
        docker ps -a --filter "publish=${registry_port}" --format '   - {{.Names}} ({{.Image}})' 2>/dev/null || true
        # shellcheck disable=SC2086  # word-splitting intended: list of container IDs
        docker rm -f $port_holders >/dev/null 2>&1 || true
        print_success "Freed port ${registry_port}"
    fi

    # Registry first, so the cluster can be wired to it on creation.
    if k3d registry create "$registry_name" --port "0.0.0.0:${registry_port}"; then
        print_success "Registry created at localhost:${registry_port}"
    else
        print_error "Failed to create registry"
        return 1
    fi

    if k3d cluster create "$cluster_name" \
        --api-port "$api_port" \
        -p "${http_port}:80@loadbalancer" \
        --k3s-arg="--kubelet-arg=max-open-files=1000000@server:*" \
        --registry-use "$registry_host" \
        --wait; then
        print_success "Cluster '$cluster_name' created"
    else
        print_error "Failed to create cluster"
        return 1
    fi

    # Point kubectl at the new cluster and verify access.
    kubectl config use-context "k3d-${cluster_name}"
    if kubectl cluster-info >/dev/null 2>&1; then
        print_success "Cluster is accessible (context: $(kubectl config current-context))"
        kubectl get nodes
    else
        print_error "Cannot access cluster"
        return 1
    fi

    print_success "Registry ready at localhost:${registry_port} — in-cluster: ${registry_host}/<image>:<tag>"
}
