# components/ — ComponentDefinitions

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

Deployable building blocks a developer can request by `type` in their
Application. Two flavours:

- **Workload components** — `web-service`, `worker`, `cron-job`. Wrap a
  Deployment/Job with sane defaults.
- **Resource claims** — starting with **`bucket`** (S3), later `database`,
  `queue`. The developer claims the resource; the component resolves to a backend
  in [`../compositions/`](../compositions/) — **Crossplane (Track 1)** or **ACK
  (Track 2)** — chosen on the platform side. The developer never sees the cloud
  primitive and the claim YAML is identical across backends.

## Conventions

- Intent-based parameters with `// +usage=` docs.
- For claims, include `healthPolicy` + `customStatus` so `vela status` shows real
  provisioning progress (e.g. surfacing the provisioned ARN/endpoint).
- Keep cloud-specific detail inside the composition, not the component — that is
  what keeps the interface vendor-neutral.

> 🚧 First component to build: **`bucket`** (S3 claim). It must resolve cleanly
> against both the Crossplane and ACK compositions in `../compositions/s3/`
> without the developer-facing parameters changing.
