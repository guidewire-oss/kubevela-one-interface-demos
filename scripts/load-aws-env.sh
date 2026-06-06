#!/usr/bin/env bash
# Look for .env.aws: source it if present, otherwise write a template.
#
# A reusable function with a skip option (checks for .env.aws, sources it, or
# writes a credentials template).
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# load_aws_env [--skip] [env_file]
#
# Behaviour:
#   - env_file exists       -> source it (exports AWS_* into the caller), return 0.
#   - missing, --skip given  -> write template, return 0 (caller continues without creds).
#   - missing, no --skip     -> write template, return 1 (caller should stop).
#
# Default env_file is ".env.aws" in the current directory.
load_aws_env() {
    local skip=false
    local env_file=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            --skip|skip) skip=true ;;
            *)           env_file="$arg" ;;
        esac
    done
    env_file="${env_file:-.env.aws}"

    if [ -f "$env_file" ]; then
        # Auto-export every var the file sets, so kubectl/aws/etc. inherit them.
        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a
        print_success ".env.aws found and sourced: $env_file"
        return 0
    fi

    # Not present — create a template.
    print_warning ".env.aws not found; creating template at $env_file"
    cat > "$env_file" <<'EOF'
# AWS Credentials for Crossplane
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_DEFAULT_REGION=us-west-2
EOF
    print_success "Template created. Edit $env_file with your AWS credentials."

    if [ "$skip" = true ]; then
        print_warning "Skip enabled — continuing without AWS credentials."
        return 0
    fi
    print_error "AWS credentials required: edit $env_file and re-run."
    return 1
}
