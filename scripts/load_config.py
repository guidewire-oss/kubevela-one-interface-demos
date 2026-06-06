#!/usr/bin/env python3
"""Parse a demo config.yaml and emit shell `export` lines on stdout.

Takes the config path as an argument so each demo can supply its own config.yaml.

Usage:
    python3 load_config.py <path/to/config.yaml>

stdout: shell `export KEY="value"` lines (intended to be eval'd by the caller).
stderr: a human-readable summary of the loaded configuration.
"""
import shlex
import sys

import yaml


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: load_config.py <path/to/config.yaml>", file=sys.stderr)
        return 2

    config_path = sys.argv[1]
    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    # Keys consumed by the demo scripts.
    values = {
        "CLUSTER_NAME": config["cluster"]["name"],
        "API_PORT": config["cluster"]["api_port"],
        "HTTP_PORT": config["cluster"]["http_port"],
        "CROSSPLANE_NAMESPACE": config["crossplane"]["namespace"],
        "MIN_CRDS": config["crossplane"]["min_crds"],
        "SETUP_DIR": config["setup"]["manifests_dir"],
    }

    for key, value in values.items():
        print(f"export {key}={shlex.quote(str(value))}")

    print("Configuration loaded successfully:", file=sys.stderr)
    print(f"  Cluster name: {values['CLUSTER_NAME']}", file=sys.stderr)
    print(f"  API port: {values['API_PORT']}", file=sys.stderr)
    print(f"  HTTP port: {values['HTTP_PORT']}", file=sys.stderr)
    print(f"  Crossplane namespace: {values['CROSSPLANE_NAMESPACE']}", file=sys.stderr)
    print(f"  Minimum CRDs: {values['MIN_CRDS']}", file=sys.stderr)
    print(f"  Setup directory: {values['SETUP_DIR']}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
