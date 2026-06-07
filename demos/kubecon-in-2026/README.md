# KubeCon India 2026 — One Interface To Rule Them All

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

**Session:** K8s Complexity Tamed: One Interface To Rule Them All With CNCF
Incubating Project KubeVela
**Speakers:** Jerrin Francis & Gowtham S, Guidewire Software India
**When:** Thursday, June 18, 2026 · 4:10–4:40 PM IST · Lotus 3 (Level 3)

## The arc

Platform fragmentation forced developers to master observability, auth, cost
control, and more just to deploy a service. This demo shows how KubeVela + OAM
turned that fragmented ecosystem into one unified interface:

1. **The problem** — the complexity iceberg; the IaC ceiling (monolithic state,
   drift, the two-plane problem).
2. **The model** — platform team defines reusable building blocks (the How);
   developers declare needs in one YAML (the What).
3. **The payoff** — reusable traits auto-inject observability, compliance, and HA;
   one workload definition deploys code *and* provisions cloud resources.
4. **Looking ahead** — Defkit: Go-native authoring of the interface itself.

## Prerequisites

```bash
# From this demo directory (demos/kubecon-in-2026/)
./init.sh     # cluster + KubeVela + Crossplane
./setup.sh    # platform building blocks + sample app
```

## Run the demo

Follow [`walkthrough.md`](walkthrough.md) — it maps each slide beat to the exact
commands and the building blocks they exercise.

## What this scenario reuses

| Beat | Uses |
|------|------|
| Declare an app, get HA for free | [`kubevela/web-service.yaml`](kubevela/web-service.yaml) + [`high-availability` trait](../../platform/kubevela/traits/high-availability/) |
| Claim an **S3 bucket** from the same YAML — Crossplane then ACK | `../../platform/kubevela/components/` (`bucket`) + [`../../platform/crossplane/s3/`](../../platform/crossplane/s3/) (🚧) |
| Extend the interface in Go | [`../../defkit/`](../../defkit/) |

> 🚧 Build order: (1) `bucket` component + Crossplane S3 composition, (2) ACK S3
> composition behind the identical claim, then extend the walkthrough's beat 5 to
> show the Track 1 → Track 2 swap. Observability trait and Defkit module follow.
