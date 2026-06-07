# components/ — ComponentDefinitions

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

Deployable building blocks a developer can request by `type` in their
Application. Two flavours:

- **Workload components** — `web-service`, `worker`, `cron-job`. Wrap a
  Deployment/Job with sane defaults.
- **Resource claims** — starting with **`bucket`** (S3), later `database`,
  `queue`. The developer claims the resource; the component resolves to a backend
  chosen on the platform side — **Crossplane (Track 1)** in [`../../crossplane/s3/`](../../crossplane/s3/)
  or **ACK (Track 2)** in `../../ack/s3/` (later). The developer never sees the cloud
  primitive and the claim YAML is identical across backends.

## Available components

| Component | File | What it does |
|-----------|------|--------------|
| **`bucket`** | `bucket.cue` | S3 bucket **claim** (composite). Resolves to the `XS3Bucket` composite → the Crossplane Composition in [`../../crossplane/s3/`](../../crossplane/s3/). Backend-swappable (Crossplane today, ACK later). Versioning is a parameter. **Use this for the one-interface story.** |
| `s3-bucket` | `s3-bucket.cue` | **Direct** S3 bucket — wraps the AWS `Bucket` managed resource itself (no XRD/Composition). Pair with the `s3-versioning` trait. Not backend-swappable; an alternative pattern. |

## Conventions

- Intent-based parameters with `// +usage=` docs.
- For claims, include `healthPolicy` + `customStatus` so `vela status` shows real
  provisioning progress (e.g. surfacing the provisioned ARN/endpoint).
- Keep cloud-specific detail inside the composition, not the component — that is
  what keeps the interface vendor-neutral (the `bucket` claim follows this; the
  direct `s3-bucket` deliberately does not).
