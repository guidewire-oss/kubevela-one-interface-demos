#!/usr/bin/env bash
set -euo pipefail
# setup.sh — Install platform building blocks and deploy the sample app for THIS demo.
#
# Run AFTER ./init.sh has bootstrapped the cluster. This applies the
# platform-team building blocks (the How) and then deploys a developer-facing
# Application (the What) to prove the one-interface model end to end.
#
# STATUS: scaffold. Steps below are stubbed — fill them in as platform/ and
# apps/ gain real definitions.

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "$REPO_ROOT/scripts/common.sh"

print_step "KubeVela: One Interface — platform + app setup"

print_step "Phase 1: Apply platform building blocks (the How)"
print_warning "TODO: apply ComponentDefinitions, TraitDefinitions, PolicyDefinitions"
# vela def apply $REPO_ROOT/platform/traits/high-availability/high-availability.cue
# vela def apply $REPO_ROOT/platform/components/...
# kubectl apply -f $REPO_ROOT/platform/compositions/

print_step "Phase 2: Deploy sample application (the What)"
print_warning "TODO: deploy this demo's KubeVela Application(s)"
# vela up -f $DEMO_DIR/kubevela/web-service.yaml

print_step "Phase 3: Verify"
print_warning "TODO: check app status and exercise the running service"
# vela status <app>
# kubectl get pods,hpa,pdb -A

print_success "Setup scaffold complete. See ./README.md and ./walkthrough.md for the walkthrough."
