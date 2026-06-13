#!/usr/bin/env bash
# Install Google Config Connector (KCC): the operator, plus a cluster-mode
# ConfigConnector wired to a service-account-key secret.
#
# Track 3 of the one-interface story (KubeVela + KCC + GCS): KCC reconciles the
# same developer `bucket` claim that Crossplane (Track 1) and ACK (Track 2) do.
# The operator is a kubectl-applied release bundle (NOT a Helm chart); once the
# ConfigConnector CR is reconciled, the operator stands up cnrm-controller-manager
# in cnrm-system, which authenticates with the `gcp-key` secret (data key
# `key.json`) that create_gcp_secret builds.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# install_kcc [secret_name] [version] [configconnector_manifest]
#
# Steps: download + apply the operator bundle → wait for the operator → ensure
# the gcp-key secret exists in cnrm-system → apply a cluster-mode ConfigConnector
# → wait for cnrm-controller-manager.
#
# Defaults:
#   secret_name             gcp-key   (matches create_gcp_secret's default + KCC convention)
#   version                 latest    (release-bundle channel on the public GCS bucket)
#   configconnector_manifest ""       (apply this file if given; else use the inline CR)
#
# ConfigConnector source: when a manifest path is passed (and exists), it is
# applied verbatim — keep its spec.credentialSecretName in sync with secret_name.
# When omitted, an equivalent cluster-mode CR is applied inline, so the function
# stays self-contained for standalone use.
#
# Credentials: if create_gcp_secret is sourced (it usually is, alongside this
# file), this function creates/refreshes the secret in cnrm-system from the
# GOOGLE_APPLICATION_CREDENTIALS key file that load_gcp_env exported. Otherwise
# the secret must already exist in cnrm-system.
install_kcc() {
    local secret_name="${1:-gcp-key}"
    local version="${2:-latest}"
    local cc_manifest="${3:-}"
    local operator_ns="configconnector-operator-system"
    local cnrm_ns="cnrm-system"
    local bundle_url="https://storage.googleapis.com/configconnector-operator/${version}/release-bundle.tar.gz"

    print_step "Installing Config Connector (KCC) operator [$version]"

    # 1. Fetch + apply the operator bundle (kubectl-applied YAML, not Helm).
    local tmp tgz
    tmp="$(mktemp -d)"
    tgz="$tmp/release-bundle.tar.gz"
    print_warning "Downloading operator bundle: $bundle_url"
    if ! curl -sSL -o "$tgz" "$bundle_url"; then
        print_error "Failed to download Config Connector operator bundle"
        rm -rf "$tmp"
        return 1
    fi
    if ! tar xzf "$tgz" -C "$tmp"; then
        print_error "Failed to extract operator bundle"
        rm -rf "$tmp"
        return 1
    fi
    print_warning "Applying operator manifests..."
    if ! kubectl apply -f "$tmp/operator-system/configconnector-operator.yaml"; then
        print_error "Failed to apply Config Connector operator"
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"

    # 2. Wait for the operator StatefulSet to roll out (rollout status watches,
    #    so it tolerates the pod not existing the instant after apply).
    print_warning "Waiting for the operator to roll out..."
    if ! kubectl rollout status statefulset/configconnector-operator \
        --namespace "$operator_ns" --timeout=300s; then
        print_error "Config Connector operator failed to become ready"
        return 1
    fi
    print_success "Config Connector operator is ready"

    # The ConfigConnector CRD ships in the bundle — make sure it's established
    # before we apply the CR below.
    kubectl wait --for=condition=established \
        crd/configconnectors.core.cnrm.cloud.google.com --timeout=120s >/dev/null 2>&1 || true

    # 3. Ensure the cnrm-system namespace + gcp-key secret exist BEFORE the
    #    controller starts (it mounts the secret at boot).
    if command -v create_gcp_secret >/dev/null 2>&1; then
        print_warning "Ensuring GCP credentials secret '$secret_name' in '$cnrm_ns'..."
        create_gcp_secret --create-namespace "$cnrm_ns" "$secret_name" || return 1
    else
        if ! kubectl get secret "$secret_name" -n "$cnrm_ns" >/dev/null 2>&1; then
            print_error "Secret '$secret_name' not found in '$cnrm_ns' and create_gcp_secret unavailable — source create-gcp-secret.sh (or create the secret) first."
            return 1
        fi
        print_success "Using existing credentials secret '$secret_name'"
    fi

    # 4. Apply the cluster-mode ConfigConnector. This is a cluster-scoped
    #    singleton; KCC fixes its name to configconnector.core.cnrm.cloud.google.com.
    #    Prefer the provided manifest (the versioned platform asset); otherwise
    #    apply an equivalent CR inline so the function stays self-contained.
    if [ -n "$cc_manifest" ]; then
        if [ ! -f "$cc_manifest" ]; then
            print_error "ConfigConnector manifest not found: $cc_manifest"
            return 1
        fi
        print_warning "Applying ConfigConnector from $cc_manifest"
        if ! kubectl apply -f "$cc_manifest"; then
            print_error "Failed to apply ConfigConnector resource"
            return 1
        fi
    else
        print_warning "Applying cluster-mode ConfigConnector (credentialSecretName=$secret_name)..."
        if ! kubectl apply -f - <<EOF
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  credentialSecretName: "$secret_name"
EOF
        then
            print_error "Failed to apply ConfigConnector resource"
            return 1
        fi
    fi

    # 5. The operator creates cnrm-controller-manager in cnrm-system only after
    #    it reconciles the ConfigConnector, so poll for the StatefulSet to appear
    #    before waiting on its rollout.
    print_warning "Waiting for cnrm-controller-manager to be created..."
    local i
    for i in $(seq 1 60); do
        if kubectl get statefulset cnrm-controller-manager -n "$cnrm_ns" >/dev/null 2>&1; then
            break
        fi
        if [ "$i" -eq 60 ]; then
            print_error "cnrm-controller-manager StatefulSet never appeared in '$cnrm_ns'"
            return 1
        fi
        sleep 5
    done

    print_warning "Waiting for cnrm-controller-manager to roll out..."
    if kubectl rollout status statefulset/cnrm-controller-manager \
        --namespace "$cnrm_ns" --timeout=600s; then
        print_success "Config Connector controller is ready"
    else
        print_error "cnrm-controller-manager failed to become ready"
        return 1
    fi

    kubectl get pods -n "$cnrm_ns"
}
