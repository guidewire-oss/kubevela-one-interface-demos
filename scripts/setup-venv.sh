#!/usr/bin/env bash
# Create (if missing) and activate a Python virtual environment, optionally
# installing a requirements file into it.
#
# Source this file; do not execute it — activation must happen in the caller's
# shell (a sourced function runs in the caller's process, so `source .../activate`
# persists after it returns).

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# setup_venv <venv_dir> [requirements_file]
#   - venv_dir missing  -> create it, activate, upgrade pip, and (only if a
#                          requirements_file is given AND exists) install it.
#   - venv_dir present  -> just activate it.
# If requirements_file is omitted, the venv is created/activated with no installs.
setup_venv() {
    local venv_dir="$1"
    local requirements="${2:-}"

    if [ -z "$venv_dir" ]; then
        print_error "setup_venv: a venv directory path is required"
        return 1
    fi

    if [ ! -d "$venv_dir" ]; then
        print_warning "Python virtual environment not found. Creating at $venv_dir..."
        python3 -m venv "$venv_dir"
        # shellcheck source=/dev/null
        source "$venv_dir/bin/activate"
        pip3 install --upgrade pip
        if [ -n "$requirements" ] && [ -f "$requirements" ]; then
            pip3 install -r "$requirements"
        fi
        print_success "Virtual environment created at $venv_dir"
    else
        print_success "Virtual environment found at $venv_dir"
        # shellcheck source=/dev/null
        source "$venv_dir/bin/activate"
    fi
}
