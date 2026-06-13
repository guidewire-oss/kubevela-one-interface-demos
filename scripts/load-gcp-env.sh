#!/usr/bin/env bash
# Look for .env.gcp: source it if present, otherwise write a template.
#
# A reusable function with a skip option (checks for .env.gcp, sources it, or
# writes a credentials template). The GCP/KCC analogue of load-aws-env.sh.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# load_gcp_env [--skip] [env_file]
#
# Behaviour (identical contract to load_aws_env):
#   - env_file exists       -> source it (exports GOOGLE_*/GCP_* into the caller), return 0.
#   - missing, --skip given  -> write template, return 0 (caller continues without creds).
#   - missing, no --skip     -> write template, return 1 (caller should stop).
#
# Default env_file is ".env.gcp" in the current directory.
#
# Unlike AWS (inline access key + secret), GCP/KCC authenticates with a
# service-account JSON key. The env file therefore carries the *path* to that
# key (GOOGLE_APPLICATION_CREDENTIALS) plus the target project and region;
# downstream the KCC secret is built from the key file's contents.
load_gcp_env() {
    local skip=false
    local env_file=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            --skip|skip) skip=true ;;
            *)           env_file="$arg" ;;
        esac
    done
    env_file="${env_file:-.env.gcp}"

    if [ -f "$env_file" ]; then
        # Auto-export every var the file sets, so gcloud/kubectl/etc. inherit them.
        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a
        print_success ".env.gcp found and sourced: $env_file"

        # The key path is the one field that must resolve to a real file; warn
        # early if it's set but missing, so the failure isn't deferred to the
        # secret-build step.
        if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
            print_warning "GOOGLE_APPLICATION_CREDENTIALS points at a missing file: ${GOOGLE_APPLICATION_CREDENTIALS}"
        fi
        return 0
    fi

    # Not present — create a template.
    print_warning ".env.gcp not found; creating template at $env_file"
    cat > "$env_file" <<'EOF'
# GCP Credentials for KubeVela + Config Connector (KCC)
# Target project to provision cloud resources into (required).
GOOGLE_PROJECT_ID=your-gcp-project-id
# Path to a service-account JSON key with the roles KCC needs (required).
# The KCC credentials secret is built from this file's contents (key.json).
GOOGLE_APPLICATION_CREDENTIALS=./gcp-key.json
# Default region for provisioned resources.
GOOGLE_REGION=us-central1
EOF
    print_success "Template created. Edit $env_file with your GCP project + key path."

    if [ "$skip" = true ]; then
        print_warning "Skip enabled — continuing without GCP credentials."
        return 0
    fi
    print_error "GCP credentials required: edit $env_file and re-run."
    return 1
}
