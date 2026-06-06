#!/usr/bin/env bash
set -euo pipefail
# cleanup.sh — Tear down THIS demo's local environment.
#
# Tears down what init.sh provisions. Deleting the k3d cluster removes everything
# inside it (Crossplane, the AWS provider/secret/ProviderConfig, KubeVela, apps),
# so cleanup only needs to drop the cluster, registry, and kubectl context.
#
# Kept for reuse: this demo's files (config.yaml, kubevela/, .venv, .env.aws) and
# the shared platform/ + scripts/ tooling at the repo root.

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"

REGISTRY_NAME="registry.localhost"

print_step "KubeVela: One Interface — demo cleanup"

# Resolve the cluster name from this demo's config (fallback to the default).
# Reuses the shared parser; if PyYAML/parse fails, the default below is used.
CLUSTER_NAME="kubecon-in-2026"
if [ -f "$DEMO_DIR/config.yaml" ]; then
    if cfg_exports="$(python3 "$REPO_ROOT/scripts/load_config.py" "$DEMO_DIR/config.yaml" 2>/dev/null)"; then
        eval "$cfg_exports"
    fi
fi

print_warning "This deletes cluster '$CLUSTER_NAME', registry '$REGISTRY_NAME', and all their data!"

print_step "Step 1: Current k3d clusters / context"
k3d cluster list || true
kubectl config current-context 2>/dev/null || echo "No active context"

print_step "Step 2: Stopping background port-forwards"
# init.sh (Phase 4, install_kubevela --velaux) starts a background
# `vela port-forward ... addon-velaux 8000:8000`. Reap it so :8000 is freed.
if pkill -f "vela port-forward" 2>/dev/null; then
    print_success "Stopped vela port-forward process(es)"
else
    print_warning "No vela port-forward processes found"
fi

print_step "Step 3: Deleting k3d cluster and registry"
if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    if k3d cluster delete "$CLUSTER_NAME"; then
        print_success "Cluster '$CLUSTER_NAME' deleted"
    else
        print_error "Failed to delete cluster '$CLUSTER_NAME'"
        exit 1
    fi
else
    print_warning "Cluster '$CLUSTER_NAME' not found (may already be deleted)"
fi

if k3d registry list 2>/dev/null | grep -q "$REGISTRY_NAME"; then
    if k3d registry delete "$REGISTRY_NAME"; then
        print_success "Registry '$REGISTRY_NAME' deleted"
    else
        print_warning "Failed to delete registry '$REGISTRY_NAME'"
    fi
else
    print_warning "Registry '$REGISTRY_NAME' not found (may already be deleted)"
fi

print_step "Step 4: Cleaning up kubectl context"
CONTEXT_NAME="k3d-$CLUSTER_NAME"
if kubectl config get-contexts "$CONTEXT_NAME" >/dev/null 2>&1; then
    kubectl config delete-context "$CONTEXT_NAME" 2>/dev/null || true
    print_success "Context '$CONTEXT_NAME' removed"
else
    print_warning "Context '$CONTEXT_NAME' not found"
fi
if kubectl config get-clusters 2>/dev/null | grep -q "$CONTEXT_NAME"; then
    kubectl config delete-cluster "$CONTEXT_NAME" 2>/dev/null || true
    print_success "Cluster entry '$CONTEXT_NAME' removed"
fi

print_step "Step 5: Verification"
echo "k3d clusters:"
k3d cluster list 2>/dev/null || echo "none"
echo ""
echo "Docker containers (k3d-related):"
docker ps -a --filter "name=k3d" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "none"

print_step "Cleanup complete"
print_success "Environment torn down."
echo "Kept for reuse: this demo's files ($DEMO_DIR/{config.yaml,kubevela,.venv,.env.aws}) and the shared platform/ + scripts/ tooling."
echo "To start fresh: ./init.sh"
