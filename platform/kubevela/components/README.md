# components/ — ComponentDefinitions

Deployable building blocks a developer can request by `type` in their
Application. Two flavours:

- **Workload components** — `web-service`, `worker`, `cron-job`. Wrap a
  Deployment/Job with sane defaults.
- **Resource claims** — starting with **`bucket`** (object storage), later
  `database`, `queue`. The developer claims the resource; the component resolves
  to a backend chosen on the platform side. The `bucket` claim ships in **three
  interchangeable backings** spanning **two clouds** — the developer never sees the
  cloud primitive and the claim YAML is identical across all of them.

## Available components

| Component | File | What it does |
|-----------|------|--------------|
| **`bucket`** (Track 1 — Crossplane, AWS) | `bucket-xp.cue` | S3 bucket **claim** (composite). Resolves to the `XS3Bucket` composite → the Crossplane Composition in [`../../crossplane/s3/`](../../crossplane/s3/). |
| **`bucket`** (Track 2 — ACK, AWS) | `bucket-ack.cue` | The **same** `bucket` claim, resolved by the **ACK** S3 controller — emits a single `s3.services.k8s.aws/v1alpha1` `Bucket` with versioning + public-access-block inline (ACK has no composition layer). |
| **`bucket`** (Track 3 — KCC, GCP) | `bucket-kcc.cue` | The **same** claim, resolved by **Google Config Connector** into a `storage.cnrm.cloud.google.com` `StorageBucket` (GCS). Maps the claim's `region` to a GCP `location`. See [`../../kcc/`](../../kcc/). |
| `s3-bucket` | `s3-bucket.cue` | **Direct** S3 bucket — wraps the AWS `Bucket` managed resource itself (no XRD/Composition). Pair with the `s3-versioning` trait. Not backend-swappable; an alternative pattern. |

All three `bucket` backings share an identical parameter surface:
`name` / `region` / `versioning` / `projectName`. The bucket's actual name is
suffixed with the deploy namespace (`…-dev`/`-staging`/`-prod`) so the same claim
yields distinct, globally-unique buckets per environment.

[`example/bucket-application.yaml`](example/bucket-application.yaml) is a minimal
Application that claims nothing but a bucket — the smallest demonstration that the
same file lands on S3 or GCS depending on which backing is installed.

> **The swap:** `bucket-xp.cue`, `bucket-ack.cue`, and `bucket-kcc.cue` all register
> a ComponentDefinition named `bucket`. Apply exactly **one** (`vela def apply …`) —
> whichever is installed backs the claim. That swap, with the developer YAML
> untouched, *is* the one-interface demo (walkthrough beat 5) — and Track 3 makes it
> cross-cloud (AWS → GCP).

## Conventions

- Intent-based parameters with `// +usage=` docs.
- For claims, include `healthPolicy` + `customStatus` so `vela status` shows real
  provisioning progress (e.g. surfacing the provisioned ARN/URL).
- Keep cloud-specific detail inside the component/composition, not the developer
  Application — that is what keeps the interface vendor- and cloud-neutral (the
  `bucket` claim follows this; the direct `s3-bucket` deliberately does not).
