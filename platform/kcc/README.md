# kcc/ — Google Config Connector (KCC) platform assets

All KCC-specific platform assets live here, grouped by technology — the GCP
analogue of `platform/crossplane/`. KCC manages Google Cloud resources as native
Kubernetes objects, the same way Crossplane and ACK do for AWS.

```
kcc/
├── config-connector/   # the cluster-mode ConfigConnector CR (credential wiring)
│   └── configconnector.yaml
└── storage/            # the GCS bucket resource:
    └── examples/
        └── test-bucket.yaml   # standalone StorageBucket — apply directly to test
```

## How KCC differs from Crossplane (why this folder is lighter)

Crossplane splits a resource into a `CompositeResourceDefinition` + `Composition`
+ `Function` pipeline, and installs a provider package + `ProviderConfig`. KCC has
**none of those layers**:

| Crossplane concept | KCC equivalent |
|--------------------|----------------|
| Provider package (`provider/`) | the Config Connector **operator** — installed by `scripts/install-kcc.sh` (a kubectl-applied release bundle, not per-resource YAML) |
| `ProviderConfig` (`provider-config/`) | the cluster-mode **`ConfigConnector`** CR + the `gcp-key` secret — see `config-connector/` (also applied by `install-kcc.sh`) |
| Function pipeline (`function/`) | none — KCC has no composition layer |
| XRD + Composition (`s3/`) | none — the GCS bucket is a **single direct CR** (`StorageBucket`), so there is nothing to apply before the component. `storage/` therefore holds only the standalone example; the `bucket-kcc.cue` component emits the `StorageBucket` directly. |

So KCC's shape mirrors **ACK** (Track 2) more than Crossplane: one CR carries the
bucket, its versioning, and its public-access settings inline.

## Headline resource: a bucket, one claim, three backends, two clouds

The demo's flagship cloud resource is an object-storage bucket, provisioned from
the *same* developer `bucket` claim — only the platform-side backend changes:

| Track | Backend | Cloud | Resource | Lives in |
|-------|---------|-------|----------|----------|
| **1** | Crossplane | AWS | S3 | `platform/crossplane/s3/` + `bucket-xp.cue` |
| **2** | AWS ACK | AWS | S3 | `bucket-ack.cue` (inline; ACK has no composition layer) |
| **3** | KCC | GCP | GCS | `platform/kcc/storage/` (here) + `bucket-kcc.cue` |

The `bucket` component in [`../kubevela/components/`](../kubevela/components/) and
the developer's Application stay **identical** across all three tracks. KCC is the
strongest expression of the "one interface" promise: the same claim crosses not
just backends but **clouds** (AWS → GCP).

### One cross-cloud wrinkle handled in `bucket-kcc.cue`

The `bucket` claim's `region` parameter defaults to `us-west-2` (an AWS region
name). GCP location names differ (`us-central1`, `us-west1`, or multi-regions like
`US`). `bucket-kcc.cue` maps the claim's `region` to a valid GCS `spec.location`
(e.g. `us-west-2` → `us-west1`, `ap-south-1` → `asia-south1`) — the developer YAML
does not change; the translation lives in the platform component, not the claim.

## How these get applied

- `scripts/install-kcc.sh` (via `demos/kubecon-in-2026/gcp-setup/init-with-kcc.sh`)
  installs the operator, applies the `ConfigConnector` CR (from
  `config-connector/configconnector.yaml`), and creates the `gcp-key` secret in
  `cnrm-system`.
- `demos/kubecon-in-2026/gcp-setup/setup-with-kcc.sh` applies `bucket-kcc.cue`
  (`vela def apply`), creates the per-namespace `gcp-key` app secrets, and deploys
  the GCP Application (`kubevela/product-catalog-gcp.yaml`).
- `storage/examples/test-bucket.yaml` is a standalone `StorageBucket` you can
  `kubectl apply` to verify KCC provisions a real GCS bucket **without** KubeVela.
- Teardown is clean: the `StorageBucket` carries the
  `cnrm.cloud.google.com/force-destroy: "true"` annotation, so deleting the
  Application empties and removes the bucket (no manual cleanup, unlike the ACK track).
