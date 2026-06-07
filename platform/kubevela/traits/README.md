# traits/ — TraitDefinitions

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

Cross-cutting capabilities the platform team auto-injects onto components. This
is the heart of the theme: developers declare *intent* and traits supply the
*implementation* of observability, compliance, HA, and security.

Author intent-based parameters — `level: prod`, not raw HPA numbers. The trait
maps intent to the underlying Kubernetes resources.

## Available traits

| Trait | Status | What it injects |
|-------|--------|-----------------|
| [`high-availability/`](high-availability/) | ✅ example | HPA + PodDisruptionBudget + topology spread + pod anti-affinity, selected by `level` (dev/staging/prod/prod-local). |
| `observability/` | 🚧 planned | Prometheus scrape annotations, ServiceMonitor, dashboards — zero developer config. |
| `compliance/` | 🚧 planned | Required labels/tags, security context, network policy — governance that "runs itself". |

```bash
vela def apply high-availability/high-availability.cue
vela def get high-availability        # see the developer-facing parameters
```
