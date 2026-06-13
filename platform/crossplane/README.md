# crossplane/ — Crossplane platform assets (AWS S3, Track 1)

All Crossplane-specific platform assets live here, grouped by technology: the AWS
provider package, the `ProviderConfig` that wires it to credentials, and per-resource
composite definitions + compositions (the cloud-resource implementations a component
claim resolves to).

```
crossplane/
├── function/          # Crossplane Functions used by Composition pipelines
│   └── function-patch-and-transform.yaml
├── provider/          # Provider packages
│   ├── provider-aws-s3.yaml       # AWS S3 provider
│   └── provider-kubernetes.yaml   # Kubernetes provider (+ runtime/RBAC)
├── provider-config/   # ProviderConfigs
│   ├── aws-provider-config.yaml         # → aws-credentials secret
│   └── kubernetes-provider-config.yaml  # InjectedIdentity (no secret)
└── s3/                # the S3 resource:
    ├── definition.yaml   # CompositeResourceDefinition (the org "bucket" API)
    └── composition.yaml  # maps it → Crossplane AWS S3 Bucket managed resources
```

`aws-setup/init-with-xp.sh` installs the function + providers + provider-configs
(cluster-level Crossplane extensions); `aws-setup/setup-with-xp.sh` applies `s3/`
(the resource definition + composition).

Crossplane extends Kubernetes to manage S3 as native objects: no state files,
continuous drift reconciliation, one control plane.

## The `bucket` claim: one interface, swappable implementation

A bucket is the demo's flagship cloud resource, provisioned from the *same*
developer Application across **three interchangeable backings** — only the
platform-side implementation changes:

| Track | Backing | Cloud | Lives in |
|-------|---------|-------|----------|
| **1** | Crossplane | AWS S3 | `platform/crossplane/s3/` (here) + `bucket-xp.cue` |
| **2** | AWS ACK | AWS S3 | `bucket-ack.cue` (inline; ACK has no composition layer) |
| **3** | Google Config Connector (KCC) | GCP GCS | [`../kcc/`](../kcc/) + `bucket-kcc.cue` |

The `bucket` component in [`../kubevela/components/`](../kubevela/components/) and the
developer's Application stay **identical** across all three. Switching tracks swaps
only the backing — that's the "one interface to rule them all" promise applied to
infrastructure; Track 3 even crosses clouds (AWS → GCP). A bucket is first because
it provisions reliably on stage and exists identically across all three backings,
making the side-by-side swap the clearest.

## How these (Crossplane) assets get applied

- `aws-setup/init-with-xp.sh` applies `function/`, then `provider/`, then
  `provider-config/` (after the `aws-credentials` secret exists) — see
  `scripts/apply-crossplane-function.sh` and `scripts/apply-crossplane-provider*.sh`.
- `aws-setup/setup-with-xp.sh` applies `s3/` (definition + composition) as part of
  the platform building blocks, before deploying the Application that claims a bucket.

The S3 `definition.yaml`/`composition.yaml` use the API group `platform.example.com`
(composite kind `XS3Bucket`). The composition sets `forceDestroy: true` so the bucket
empties on teardown. The bucket name is the claim's `spec.name` suffixed with the
deploy namespace (`…-dev`/`-staging`/`-prod`) for per-environment uniqueness. They
pair with `bucket-xp.cue` in `../kubevela/components/`.
