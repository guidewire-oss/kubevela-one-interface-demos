# platform/ — The How

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

This is the **platform team's** space. Everything here encapsulates best
practices, governance, and cloud wiring so that application developers never
have to. Definitions are authored in CUE (or in Go via [`../defkit/`](../defkit/),
which compiles to identical CUE).

A developer's `Application` in [`../apps/`](../apps/) references these by name —
`type: web-service`, `traits: [{type: high-availability}]` — and gets the full
implementation without seeing it.

## Contents

| Directory | KubeVela kind | Purpose |
|-----------|---------------|---------|
| [`components/`](components/) | `ComponentDefinition` | Deployable building blocks a developer can request — web services, workers, and **claims** for cloud resources (database, bucket, queue). |
| [`traits/`](traits/) | `TraitDefinition` | Cross-cutting capabilities auto-injected onto components — HA, observability, compliance, security context. This is where "auto-inject best practices" lives. |
| [`policies/`](policies/) | `PolicyDefinition` | App-wide governance — topology (which clusters/namespaces), per-environment overrides, guardrails. |
| [`crossplane/`](crossplane/) | Crossplane `Provider` / `ProviderConfig` / `XRD` + `Composition` | All Crossplane assets (provider, provider-config, per-resource definition + composition) — the cloud-resource implementations a component claim resolves to. Vendor-neutral: Track 2 swaps in ACK (`../ack/`) without touching the developer's Application. |

## Authoring a definition

```bash
# From CUE
vela def apply platform/traits/high-availability/high-availability.cue

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
