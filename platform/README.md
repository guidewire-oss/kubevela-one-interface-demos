# platform/ — The How

This is the **platform team's** space. Everything here encapsulates best
practices, governance, and cloud wiring so that application developers never
have to. Definitions are authored in CUE (or in Go via [`../defkit/`](../defkit/),
which compiles to identical CUE).

A developer's `Application` in [`../apps/`](../apps/) references these by name —
`type: web-service`, `traits: [{type: high-availability}]` — and gets the full
implementation without seeing it.

## Contents

Grouped by technology:

### [`kubevela/`](kubevela/) — KubeVela X-Definitions

| Directory | KubeVela kind | Purpose |
|-----------|---------------|---------|
| [`kubevela/components/`](kubevela/components/) | `ComponentDefinition` | Deployable building blocks a developer can request — web services, workers, and **claims** for cloud resources. The `bucket` claim ships in three interchangeable backings (`bucket-xp` / `bucket-ack` / `bucket-kcc`). |
| [`kubevela/traits/`](kubevela/traits/) | `TraitDefinition` | Cross-cutting capabilities auto-injected onto components — HA, observability, compliance, security context. This is where "auto-inject best practices" lives. |
| [`kubevela/policies/`](kubevela/policies/) | `PolicyDefinition` | App-wide governance — topology (which clusters/namespaces), per-environment overrides, guardrails. |

### [`crossplane/`](crossplane/) — Crossplane assets (AWS S3)

`Provider` / `ProviderConfig` / `Function` / `XRD` + `Composition` — the AWS S3
implementation the `bucket` claim resolves to on Track 1.

### [`kcc/`](kcc/) — Google Config Connector assets (GCP GCS)

The GCP analogue, lighter because KCC has no XRD/Composition/Function layer: the
`ConfigConnector` (credential wiring) plus a `StorageBucket` example. This is what
the `bucket` claim resolves to on Track 3 — the same developer claim, a different
cloud.

> **Vendor- and cloud-neutral by design.** The `bucket` claim is identical across
> Track 1 (Crossplane → AWS S3), Track 2 (ACK → AWS S3), and Track 3 (KCC → GCP GCS).
> Install one backing; the developer's Application never changes. ACK's manifests
> live inline in `bucket-ack.cue` (ACK has no composition layer, like KCC).

## Authoring a definition

```bash
# From CUE
vela def apply platform/kubevela/traits/high-availability/high-availability.cue

# Inspect what a definition exposes to developers
vela def get high-availability
```

Conventions:

- One definition per file; group related files in a subdirectory.
- Every `parameter` field carries a `// +usage=` comment — that text is what the
  developer sees via `vela def get`.
- Definitions wrapping external resources include `healthPolicy` and
  `customStatus` so `vela status` reflects real provisioning state.
- Keep parameters **minimal and intent-based**. Expose `level: dev|staging|prod`,
  not raw HPA min/max — the trait maps intent to implementation.
