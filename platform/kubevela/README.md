# kubevela/ — KubeVela X-Definitions

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

All KubeVela definitions live here, grouped by technology (KubeVela) like
`../crossplane/` groups the Crossplane assets. These are the building blocks a
developer references by name from their `Application`; the platform team owns them.

```
kubevela/
├── components/   # ComponentDefinitions — workloads + resource claims (bucket, …)
├── traits/       # TraitDefinitions — auto-injected HA, observability, compliance, …
└── policies/     # PolicyDefinitions — topology, per-env overrides, guardrails
```

Authored in CUE (or in Go via [`../../defkit/`](../../defkit/), which compiles to
identical CUE). Applied with `vela def apply` (see `setup.sh` Phase 1).

```bash
vela def apply platform/kubevela/traits/high-availability/high-availability.cue
vela def get high-availability     # what the definition exposes to developers
```

Conventions:
- One definition per file; group related files in a subdirectory.
- Every `parameter` field carries a `// +usage=` comment — that text is what the
  developer sees via `vela def get`.
- Definitions wrapping external resources include `healthPolicy` and `customStatus`
  so `vela status` reflects real provisioning state.
- Keep parameters **minimal and intent-based** (`level: dev|staging|prod`, not raw
  HPA min/max) — the definition maps intent to implementation.
