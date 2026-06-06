#!/usr/bin/env bash
# Shared helpers for init.sh / setup.sh. Source this file; do not execute it.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# printf '%b' interprets the \033 escapes in the color vars (portable across
# bash and zsh; plain `echo` prints them literally in bash).
print_step() {
    printf '\n'
    printf '%b\n' "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    printf '%b\n' "${BLUE}$1${NC}"
    printf '%b\n' "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    printf '\n'
}

print_success() { printf '%b\n' "${GREEN}✓ $1${NC}"; }
print_warning() { printf '%b\n' "${YELLOW}⚠ $1${NC}"; }
print_error()   { printf '%b\n' "${RED}✗ $1${NC}"; }

# require_tools <tool> [<tool> ...] — exit non-zero if any tool is missing.
require_tools() {
    local missing=false tool
    for tool in "$@"; do
        if command -v "$tool" >/dev/null 2>&1; then
            print_success "$tool is installed"
        else
            print_error "$tool is NOT installed"
            missing=true
        fi
    done
    [ "$missing" = false ]
}
