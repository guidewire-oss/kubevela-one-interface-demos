# compositions/ — Cloud-resource implementations

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

The implementation a resource-claim component resolves to. This is the platform
side of "one interface, swappable implementation": the developer claims an **S3
bucket** from one Application, and what actually provisions it is chosen here —
**without changing the developer's YAML**.

## Headline resource: S3 (two tracks)

S3 is the demo's flagship cloud resource. We support two interchangeable
backends, built in this order:

| Track | Path | Backend | Status |
|-------|------|---------|--------|
| **1 (first target)** | [`s3/crossplane/`](s3/crossplane/) | Crossplane `XRD` + `Composition` (AWS provider) | 🚧 |
| **2 (second target)** | [`s3/ack/`](s3/ack/) | AWS ACK S3 controller (`Bucket` CRD) | 🚧 |

The whole point: the `bucket` component in [`../components/`](../components/) and
the developer's Application stay **identical** across both tracks. Switching
Track 1 → Track 2 swaps only what lives in these directories. That is the "one
interface to rule them all" promise applied to infrastructure.

### Track 1 — Crossplane + S3

```
s3/crossplane/
├── xrd.yaml          # CompositeResourceDefinition — the org "Bucket" API
└── composition.yaml  # maps Bucket → Crossplane AWS S3 Bucket managed resource
```

Crossplane extends Kubernetes to manage S3 as native objects: no state files,
continuous drift reconciliation, one control plane.

### Track 2 — ACK + S3

```
s3/ack/
└── bucket.yaml       # ACK s3.services.k8s.aws Bucket the claim resolves to
```

AWS ACK provisions the same S3 bucket via first-party AWS controllers. Same
developer interface, different implementation — the comparison beat of the demo.

## Why S3 first

S3 is simple enough to provision reliably on stage, has a clean one-bucket claim
shape, and exists identically across both Crossplane and ACK — making it the
clearest side-by-side demonstration of backend-swappability.

> 🚧 Both tracks are stubbed — Track 1 (Crossplane) is implemented first, then
> Track 2 (ACK) behind the identical claim.
