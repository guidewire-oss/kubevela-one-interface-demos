#!/usr/bin/env bash
# Install an AWS Controllers for Kubernetes (ACK) service controller via Helm,
# authenticating to AWS with a mounted credentials-file secret.
#
# Track 2 of the one-interface story (KubeVela + ACK + S3): the ACK controller
# reconciles the same developer `bucket` claim that Crossplane does in Track 1.
# It is installed from the public-ECR OCI chart and pointed at an `aws-credentials`
# secret — the `[default]` profile under key `credentials` that create_aws_secret
# builds — which the chart mounts at /var/run/secrets/aws/credentials.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# install_ack_controller [service] [region] [namespace] [release] [secret_name] [chart_version]
#
# Installs (or upgrades) the ACK <service> controller from
# oci://public.ecr.aws/aws-controllers-k8s/<service>-chart, configured to read AWS
# credentials from <secret_name> (key `credentials`, profile `default`) — the exact
# shape create_aws_secret produces.
#
# Defaults:
#   service        s3
#   region         $AWS_DEFAULT_REGION → $AWS_REGION → us-west-2
#   namespace      $ACK_NAMESPACE → ack-system
#   release        ack-<service>-controller
#   secret_name    aws-credentials
#   chart_version  "" (latest)
#
# Credentials: if create_aws_secret is sourced (it usually is, alongside this file),
# this function creates/refreshes the secret for you from the AWS_* env that
# load_aws_env exported. Otherwise the namespace and secret must already exist.
install_ack_controller() {
    local service="${1:-s3}"
    local region="${2:-${AWS_DEFAULT_REGION:-${AWS_REGION:-us-west-2}}}"
    local namespace="${3:-${ACK_NAMESPACE:-ack-system}}"
    local release="${4:-ack-${service}-controller}"
    local secret_name="${5:-aws-credentials}"
    local chart_version="${6:-}"
    local chart="oci://public.ecr.aws/aws-controllers-k8s/${service}-chart"

    print_step "Installing ACK '$service' controller into namespace '$namespace'"

    # Provision (idempotently) the AWS credentials secret the chart mounts.
    if command -v create_aws_secret >/dev/null 2>&1; then
        print_warning "Ensuring AWS credentials secret '$secret_name' in '$namespace'..."
        create_aws_secret --create-namespace "$namespace" "$secret_name" || return 1
    else
        # No secret helper sourced — namespace + secret must already exist.
        if ! kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
            print_error "Secret '$secret_name' not found in '$namespace' and create_aws_secret unavailable — source create-aws-secret.sh (or create the secret) first."
            return 1
        fi
        print_success "Using existing credentials secret '$secret_name'"
    fi

    # Install fresh, or upgrade if a release already exists in the namespace.
    local helm_cmd
    if helm list -n "$namespace" 2>/dev/null | grep -q "$release"; then
        print_warning "ACK '$service' controller already installed — upgrading..."
        helm_cmd="upgrade"
    else
        print_warning "Installing ACK '$service' controller..."
        helm_cmd="install"
    fi

    # Pin the chart version only when one was requested; otherwise take latest.
    local version_args=()
    if [ -n "$chart_version" ]; then
        version_args=(--version "$chart_version")
    fi

    # OCI charts install directly from the registry — no `helm repo add` needed.
    if helm "$helm_cmd" "$release" "$chart" \
        "${version_args[@]}" \
        --namespace "$namespace" \
        --create-namespace \
        --set aws.region="$region" \
        --set aws.credentials.secretName="$secret_name" \
        --set aws.credentials.secretKey=credentials \
        --set aws.credentials.profile=default \
        --wait \
        --timeout 10m; then
        print_success "ACK '$service' controller helm chart $helm_cmd completed"
    else
        print_error "Failed to $helm_cmd ACK '$service' controller"
        return 1
    fi

    print_warning "Waiting for ACK '$service' controller pods to be ready..."
    if kubectl wait --namespace "$namespace" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/instance=ack-"${service}"-controller \
        --timeout=600s; then
        print_success "ACK '$service' controller is ready"
    else
        print_error "ACK '$service' controller failed to become ready"
        return 1
    fi

    kubectl get pods -n "$namespace"
}
