# scripts/ — reusable bootstrap helpers

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

Small, composable shell helpers used by each demo's `init.sh` / `cleanup.sh` to
stand up a local KubeVela + Crossplane environment. They're written to be reused
piecemeal — a demo (or an AI agent, or you at a prompt) can pull in just the
functions it needs.

## Conventions (read first)

- **Source, don't execute.** Every `*.sh` here *defines functions*; it does not do
  anything on its own. Use `source <file>` then call the function. (Sourcing also
  lets functions that activate a venv or export vars affect your current shell.)
- **`common.sh` first (optional).** It provides `print_step/success/warning/error`
  and `require_tools`. Every other script has **fallback** definitions of the
  `print_*` helpers, so they work even if `common.sh` isn't sourced — but sourcing
  `common.sh` first gives consistent, coloured output.
- **Inputs are explicit.** Each function takes its inputs as positional args and/or
  reads a few documented environment variables (several of which `load_config`
  exports). Flags use a `--flag` style (`--skip`, `--velaux`, `--create-namespace`).
- **Config-driven defaults.** Many functions default to the variables that
  `load_config` exports (`CLUSTER_NAME`, `CROSSPLANE_NAMESPACE`, `MIN_CRDS`, …), so
  after `load_config` you can usually call them with no args.

### For AI agents
Each function is self-contained and idempotent where noted. To reuse one: `source`
its file, ensure any required env vars are set (see "Reads" below), and call it.
`init.sh` (`demos/kubecon-in-2026/init.sh`) is the canonical end-to-end composition
example.

## Quick reference

| Script | Function(s) | One-liner |
|--------|-------------|-----------|
| `common.sh` | `print_step/success/warning/error`, `require_tools` | Output helpers + tool-presence check |
| `setup-venv.sh` | `setup_venv` | Create (if missing) + activate a Python venv, optionally install requirements |
| `load-config.sh` (+ `load_config.py`, `requirements.txt`) | `load_config` | Parse a demo `config.yaml`, export its values, write `.env.sh` |
| `create-cluster.sh` | `create_cluster` | Create a k3d cluster wired to a local registry (frees the port first) |
| `load-aws-env.sh` | `load_aws_env` | Source `.env.aws` (export AWS creds) or write a template |
| `create-aws-secret.sh` | `create_aws_secret` | Build the `aws-credentials` k8s secret from env creds |
| `install-crossplane.sh` | `install_crossplane`, `wait_for_crossplane_crds` | Helm-install Crossplane + wait for CRDs |
| `apply-crossplane-function.sh` | `apply_crossplane_function` | Apply a Function manifest dir + wait installed/healthy |
| `apply-crossplane-provider.sh` | `apply_crossplane_provider` | Apply a provider manifest dir + wait installed/healthy |
| `apply-crossplane-provider-config.sh` | `apply_crossplane_provider_config` | Apply a ProviderConfig manifest dir |
| `install-kubevela.sh` | `install_kubevela` | `vela install` + wait, optional VelaUX |
| `install-ack.sh` | `install_ack_controller` | Helm-install an ACK controller (OCI chart) wired to the AWS creds secret (Track 2) |
| `load-gcp-env.sh` | `load_gcp_env` | Source `.env.gcp` (export GCP project + key path) or write a template |
| `create-gcp-secret.sh` | `create_gcp_secret` | Build the `gcp-key` k8s secret (data key `key.json`) from a service-account key file |
| `install-kcc.sh` | `install_kcc` | Apply the Config Connector operator + cluster-mode `ConfigConnector` wired to the `gcp-key` secret (Track 3) |
| `empty-s3-bucket.sh` | `empty_s3_bucket` | Empty an S3 bucket (objects + versions) so it can be deleted — ACK teardown helper (ACK has no force-destroy) |

---

## common.sh

Output + prerequisite helpers. Source this first for consistent coloured output.

- `print_step <msg>` / `print_success <msg>` / `print_warning <msg>` / `print_error <msg>`
  — formatted log lines (use `printf '%b'` so ANSI colours render in bash *and* zsh).
- `require_tools <tool> [<tool> …]` — prints ✓/✗ per tool; **returns non-zero** if any
  are missing.

```bash
source scripts/common.sh
require_tools python3 kubectl helm vela docker k3d || exit 1
print_step "Doing the thing"
```

## setup-venv.sh — `setup_venv <venv_dir> [requirements_file]`

Create (if missing) and **activate** a Python virtualenv; optionally install a
requirements file.

- **Args:** `venv_dir` (required); `requirements_file` (optional).
- **Behaviour:** missing venv → `python3 -m venv` → activate → upgrade pip → install
  requirements *if a path is given and the file exists*. Existing venv → just
  activate. No requirements arg → create + activate only.
- **Requires:** `python3`. **Must be sourced** (activation persists in your shell).

```bash
source scripts/setup-venv.sh
setup_venv "$DEMO_DIR/.venv" "$REPO_ROOT/scripts/requirements.txt"
# or, no deps:  setup_venv /tmp/venv
```

## load-config.sh — `load_config <config_file>`

Validate + parse a demo `config.yaml`, **export** its values, and write a `.env.sh`
next to the config (replacing any existing one), then source it.

- **Args:** path to `config.yaml`.
- **Exports:** `CLUSTER_NAME`, `API_PORT`, `HTTP_PORT`, `CROSSPLANE_NAMESPACE`,
  `MIN_CRDS`, `SETUP_DIR`.
- **Side effect:** writes `<config-dir>/.env.sh` (gitignored).
- **Requires:** `python3` with **PyYAML** (see `requirements.txt`; install via
  `setup_venv`). Parsing is done by the companion `load_config.py`.

```bash
source scripts/load-config.sh
load_config demos/kubecon-in-2026/config.yaml
echo "$CLUSTER_NAME $CROSSPLANE_NAMESPACE"
```

`load_config.py` can also be used standalone (prints `export …` lines on stdout, a
summary on stderr): `eval "$(python3 scripts/load_config.py path/to/config.yaml)"`.

## create-cluster.sh — `create_cluster [name] [api_port] [http_port] [registry_name] [registry_port]`

Recreate a k3d cluster wired to a local Docker registry; idempotent.

- **Args (all optional):** default `name=$CLUSTER_NAME`, `api_port=$API_PORT|6443`,
  `http_port=$HTTP_PORT|8090`, `registry_name=registry.localhost`, `registry_port=5000`.
- **Does:** delete any existing cluster/registry → **free the registry host port**
  (force-removes any docker container publishing it) → create registry → create
  cluster (`--registry-use`, `--wait`) → switch kubectl context → verify access.
- **Reads:** `CLUSTER_NAME`/`API_PORT`/`HTTP_PORT` (from `load_config`). **Requires:**
  `k3d`, `kubectl`, `docker`.

```bash
source scripts/create-cluster.sh
create_cluster                 # uses load_config values
create_cluster my-cluster 6443 8090
```

## load-aws-env.sh — `load_aws_env [--skip] [env_file]`

Find `.env.aws`: source it (auto-exporting `AWS_*`) if present, else write a template.

- **Args:** `--skip` (optional) anywhere; `env_file` (optional, default `.env.aws`).
- **Returns:** present → source + export, `0`. Missing + `--skip` → write template,
  `0` (caller continues). Missing, no `--skip` → write template, **`1`** (caller stops).

```bash
source scripts/load-aws-env.sh
load_aws_env "$DEMO_DIR/.env.aws"          # stop if creds missing
load_aws_env --skip "$DEMO_DIR/.env.aws"   # continue without creds
```

## create-aws-secret.sh — `create_aws_secret [--create-namespace] [namespace] [secret_name]`

Build an AWS credentials profile (incl. session token when present) and apply it as
a generic k8s secret.

- **Args:** `--create-namespace` (optional); `namespace` (default
  `$CROSSPLANE_NAMESPACE|crossplane-system`); `secret_name` (default `aws-credentials`).
- **Reads:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`
  (e.g. exported by `load_aws_env`). Errors if the first two are unset.
- **Namespace:** missing + `--create-namespace` → create it; missing without the flag
  → error. **Requires:** `kubectl`.

```bash
source scripts/create-aws-secret.sh
create_aws_secret "$CROSSPLANE_NAMESPACE" aws-credentials
create_aws_secret --create-namespace my-ns my-secret
```

## install-crossplane.sh — `install_crossplane` + `wait_for_crossplane_crds`

- `install_crossplane [namespace] [release_name]` — add the `crossplane-stable` helm
  repo, install/upgrade Crossplane (`--create-namespace --wait`), wait for the
  controller pod. Defaults `namespace=$CROSSPLANE_NAMESPACE|crossplane-system`,
  `release_name=crossplane`.
- `wait_for_crossplane_crds [min_crds] [namespace]` — poll until at least `min_crds`
  Crossplane CRDs are registered (default `$MIN_CRDS|15`).
- **Requires:** `helm`, `kubectl`.

```bash
source scripts/install-crossplane.sh
install_crossplane
wait_for_crossplane_crds
```

## apply-crossplane-function.sh — `apply_crossplane_function <function_dir>`

`kubectl apply` every manifest in `function_dir`, then wait for all Crossplane
functions to be **installed** and **healthy**. Functions (e.g.
`function-patch-and-transform`) are used by Composition pipelines. **Requires:** `kubectl`.

```bash
source scripts/apply-crossplane-function.sh
apply_crossplane_function "$REPO_ROOT/platform/crossplane/function"
```

## apply-crossplane-provider.sh — `apply_crossplane_provider <provider_dir>`

`kubectl apply` every manifest in `provider_dir`, then wait for all Crossplane
providers to be **installed** and **healthy** (registers the provider's CRDs, incl.
`aws.upbound.io` ProviderConfig). **Requires:** `kubectl`.

```bash
source scripts/apply-crossplane-provider.sh
apply_crossplane_provider "$REPO_ROOT/platform/crossplane/provider"
```

## apply-crossplane-provider-config.sh — `apply_crossplane_provider_config <dir>`

`kubectl apply` every manifest in `dir`. **Run AFTER** the provider is installed (its
CRD must exist) **and** after the referenced credentials secret exists. **Requires:**
`kubectl`.

```bash
source scripts/apply-crossplane-provider-config.sh
apply_crossplane_provider_config "$REPO_ROOT/platform/crossplane/provider-config"
```

## install-kubevela.sh — `install_kubevela [--velaux]`

`vela install` + wait for `vela-core`. With `--velaux`, also enable the VelaUX addon
and background a port-forward to http://localhost:8000. **Requires:** `vela`, `kubectl`.

```bash
source scripts/install-kubevela.sh
install_kubevela            # control plane only
install_kubevela --velaux   # + VelaUX UI
```

## install-ack.sh — `install_ack_controller [service] [region] [namespace] [release] [secret_name] [chart_version]`

Track 2 (KubeVela + ACK + S3). Helm-install/upgrade an ACK service controller from its
public-ECR **OCI** chart (`oci://public.ecr.aws/aws-controllers-k8s/<service>-chart` — no
`helm repo add` needed), wired to read AWS credentials from a mounted secret, then wait
for the controller pod. The chart's defaults (`secretKey=credentials`, `profile=default`)
match exactly what `create_aws_secret` produces, so the two compose directly.

- **Args (all optional):** `service` (default `s3`); `region` (default
  `$AWS_DEFAULT_REGION|$AWS_REGION|us-west-2`); `namespace` (default `$ACK_NAMESPACE|ack-system`);
  `release` (default `ack-<service>-controller`); `secret_name` (default `aws-credentials`);
  `chart_version` (default latest).
- **Credentials:** if `create_aws_secret` is sourced, the function creates/refreshes the
  secret in `namespace` from the exported `AWS_*` env (`load_aws_env`); otherwise the
  namespace and secret must already exist. Sets `aws.region`, `aws.credentials.secretName`,
  `aws.credentials.secretKey=credentials`, `aws.credentials.profile=default`.
- **Requires:** `helm` (with OCI support), `kubectl`.

```bash
source scripts/load-aws-env.sh
source scripts/create-aws-secret.sh
source scripts/install-ack.sh
load_aws_env "$DEMO_DIR/.env.aws"
install_ack_controller                 # ACK S3 controller into ack-system
install_ack_controller s3 us-east-1    # explicit service + region
```

## load-gcp-env.sh — `load_gcp_env [--skip] [env_file]`

The GCP/KCC analogue of `load_aws_env`. Find `.env.gcp`: source it (auto-exporting
`GOOGLE_*`/`GCP_*`) if present, else write a template.

- **Args:** `--skip` (optional) anywhere; `env_file` (optional, default `.env.gcp`).
- **Returns:** present → source + export, `0`. Missing + `--skip` → write template, `0`
  (caller continues). Missing, no `--skip` → write template, **`1`** (caller stops).
- **Template fields:** `GOOGLE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (path to a
  service-account JSON key), `GOOGLE_REGION`. Unlike AWS (inline key+secret), GCP auth
  is a key *file*, so the env file carries its path; warns early if that path is missing.

```bash
source scripts/load-gcp-env.sh
load_gcp_env "$DEMO_DIR/.env.gcp"          # stop if creds missing
load_gcp_env --skip "$DEMO_DIR/.env.gcp"   # continue without creds
```

## create-gcp-secret.sh — `create_gcp_secret [--create-namespace] [namespace] [secret_name]`

Read the service-account JSON key at `GOOGLE_APPLICATION_CREDENTIALS` and apply it as a
generic k8s secret under data key **`key.json`** — the name KCC's controller reads
(mounted at `/var/secrets/google/key.json`). The GCP analogue of `create_aws_secret`.

- **Args:** `--create-namespace` (optional); `namespace` (default `$KCC_NAMESPACE|cnrm-system`);
  `secret_name` (default `gcp-key`, matching KCC's `spec.credentialSecretName` convention).
- **Reads:** `GOOGLE_APPLICATION_CREDENTIALS` (e.g. exported by `load_gcp_env`). Errors if
  it is unset **or** the file is missing.
- **Namespace:** missing + `--create-namespace` → create it; missing without the flag →
  error. **Requires:** `kubectl`.

```bash
source scripts/create-gcp-secret.sh
create_gcp_secret                              # gcp-key in cnrm-system
create_gcp_secret --create-namespace my-ns my-key
```

## install-kcc.sh — `install_kcc [secret_name] [version] [configconnector_manifest]`

Track 3 (KubeVela + KCC + GCS). Download + `kubectl apply` the Config Connector operator
release bundle (a YAML bundle from the public GCS bucket — **not** Helm), wait for the
operator, ensure the `gcp-key` secret exists in `cnrm-system`, apply a cluster-mode
`ConfigConnector`, then wait for `cnrm-controller-manager`.

- **Args (all optional):** `secret_name` (default `gcp-key`); `version` (default `latest`,
  the release-bundle channel); `configconnector_manifest` (path — applied with
  `kubectl apply -f` if given; otherwise an equivalent CR is applied inline).
- **Credentials:** if `create_gcp_secret` is sourced, the function creates/refreshes the
  secret in `cnrm-system` from `GOOGLE_APPLICATION_CREDENTIALS` (`load_gcp_env`); otherwise
  the secret must already exist there.
- **Requires:** `kubectl`, `curl`, `tar`.

```bash
source scripts/load-gcp-env.sh
source scripts/create-gcp-secret.sh
source scripts/install-kcc.sh
load_gcp_env "$DEMO_DIR/.env.gcp"
install_kcc                                                            # inline ConfigConnector CR
install_kcc gcp-key latest "$REPO_ROOT/platform/kcc/config-connector/configconnector.yaml"
```

## empty-s3-bucket.sh — `empty_s3_bucket <bucket_name>`

Delete every object in an S3 bucket (current objects + versions + delete markers) so the
bucket can be deleted. The ACK S3 controller calls `DeleteBucket` directly and has **no
force-destroy** — unlike Crossplane (`forceDestroy: true`) and KCC
(`cnrm.cloud.google.com/force-destroy` annotation) — so a non-empty bucket blocks ACK
teardown. Empty it with this helper first, then delete the CR/Application.

- **Args:** `bucket_name` (required).
- **Reads:** `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` [/ `AWS_SESSION_TOKEN`] (exported by
  `load_aws_env`; the aws CLI picks them up). **Requires:** the `aws` CLI.
- **Behaviour:** no-op (returns 0) if the bucket is absent/inaccessible; otherwise removes all
  objects, then purges versions + delete markers (builds the delete payload via `--query`, no jq).
- Wired into `demos/kubecon-in-2026/aws-setup/teardown-with-ack.sh`, which discovers the live ACK
  bucket names (`kubectl get buckets.s3.services.k8s.aws`) and empties each before `vela delete`.

```bash
source scripts/load-aws-env.sh
source scripts/empty-s3-bucket.sh
load_aws_env "$DEMO_DIR/.env.aws"
empty_s3_bucket my-bucket-dev
```

---

## Putting it together (a full bootstrap)

This is the order `demos/kubecon-in-2026/init.sh` uses — copy it for a new demo:

```bash
source "$REPO_ROOT/scripts/common.sh"
source "$REPO_ROOT/scripts/setup-venv.sh"
source "$REPO_ROOT/scripts/load-config.sh"
source "$REPO_ROOT/scripts/create-cluster.sh"
source "$REPO_ROOT/scripts/load-aws-env.sh"
source "$REPO_ROOT/scripts/install-crossplane.sh"
source "$REPO_ROOT/scripts/create-aws-secret.sh"
source "$REPO_ROOT/scripts/apply-crossplane-function.sh"
source "$REPO_ROOT/scripts/apply-crossplane-provider.sh"
source "$REPO_ROOT/scripts/apply-crossplane-provider-config.sh"
source "$REPO_ROOT/scripts/install-kubevela.sh"

require_tools python3 kubectl helm vela docker k3d || exit 1
setup_venv "$DEMO_DIR/.venv" "$REPO_ROOT/scripts/requirements.txt"
load_config "$DEMO_DIR/config.yaml"          # exports CLUSTER_NAME, CROSSPLANE_NAMESPACE, …

create_cluster                                # uses exported config
load_aws_env "$DEMO_DIR/.env.aws"             # export AWS creds (or stop)
install_crossplane
wait_for_crossplane_crds
create_aws_secret "$CROSSPLANE_NAMESPACE" aws-credentials
apply_crossplane_function "$REPO_ROOT/platform/crossplane/function"
apply_crossplane_provider "$REPO_ROOT/platform/crossplane/provider"
apply_crossplane_provider_config "$REPO_ROOT/platform/crossplane/provider-config"
install_kubevela --velaux
```

### Track 3 variant (KCC instead of Crossplane)

`demos/kubecon-in-2026/gcp-setup/init-with-kcc.sh` swaps the cloud-orchestrator phase:
same `create_cluster` + `install_kubevela`, but the Crossplane install/function/provider
chain is replaced by a single `install_kcc`, and `load_aws_env`/`create_aws_secret` become
their GCP counterparts.

```bash
source "$REPO_ROOT/scripts/load-gcp-env.sh"
source "$REPO_ROOT/scripts/create-gcp-secret.sh"
source "$REPO_ROOT/scripts/install-kcc.sh"

create_cluster
load_gcp_env "$DEMO_DIR/.env.gcp"             # export GCP project + key path (or stop)
install_kcc gcp-key latest "$REPO_ROOT/platform/kcc/config-connector/configconnector.yaml"
install_kubevela --velaux
```
