# crossplane/ — Crossplane platform assets

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

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

`init.sh` installs the function + providers + provider-configs (cluster-level
Crossplane extensions); `setup.sh` applies `s3/` (the resource definition +
composition).

Crossplane extends Kubernetes to manage S3 as native objects: no state files,
continuous drift reconciliation, one control plane.

## Headline resource: S3, and "one interface, swappable implementation"

S3 is the demo's flagship cloud resource, provisioned two ways from the *same*
developer Application — only the platform-side backend changes:

| Track | Backend | Lives in |
|-------|---------|----------|
| **1 (now)** | Crossplane | `platform/crossplane/s3/` (here) |
| **2 (later)** | AWS ACK | `platform/ack/s3/` (to be added) |

The `bucket` component in [`../kubevela/components/`](../kubevela/components/) and the developer's
Application stay **identical** across both tracks. Switching Track 1 → Track 2 swaps
only the backend assets — that's the "one interface to rule them all" promise applied
to infrastructure. S3 is first because it's simple to provision reliably on stage and
exists identically across both backends, making the side-by-side swap the clearest.

## How these get applied

- `init.sh` applies `function/`, then `provider/`, then `provider-config/` (after the
  `aws-credentials` secret exists) — see `scripts/apply-crossplane-function.sh` and
  `scripts/apply-crossplane-provider*.sh`.
- `setup.sh` applies `s3/` (definition + composition) as part of the platform
  building blocks, before deploying the Application that claims a bucket.

The S3 `definition.yaml`/`composition.yaml` use the API group `platform.example.com`
(composite kind `XS3Bucket`); the bucket name is the claim's `spec.name` (no prefix).
They pair with the `bucket` component in `../kubevela/components/`.
