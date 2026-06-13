# KubeCon India 2026 — One Interface To Rule Them All

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

Each track is bootstrapped from its own self-contained setup folder. Pick a track:

```bash
# AWS — Crossplane (Track 1)
cd aws-setup && ./init-with-xp.sh   && ./setup-with-xp.sh

# AWS — ACK (Track 2)
cd aws-setup && ./init-with-ack.sh  && ./setup-with-ack.sh

# GCP — Config Connector / KCC (Track 3)
cd gcp-setup && ./init-with-kcc.sh  && ./setup-with-kcc.sh
```

- `init-*` creates a local k3d cluster, installs KubeVela, and installs the track's
  cloud-resource orchestrator (Crossplane / the ACK controller / the Config Connector
  operator). It reads credentials from that folder's `.env.aws` (AWS) or `.env.gcp` (GCP).
- `setup-*` applies the matching `bucket` backing (`vela def apply`), builds the app
  image, creates per-namespace credential secrets, and deploys the Application.

Tear down: `aws-setup/teardown-with-ack.sh` first on the ACK track (empties the S3
buckets — ACK has no force-destroy), then `./cleanup.sh` to delete the cluster.

## Run the demo

Follow [`walkthrough.md`](walkthrough.md) — it maps each slide beat to the exact
commands and the building blocks they exercise.

## What this scenario reuses

| Beat | Uses |
|------|------|
| Declare an app + autoscaling + a bucket in one YAML | [`kubevela/product-catalog.yaml`](kubevela/product-catalog.yaml) (`webservice` + `hpa` + `bucket` claim); GCP variant [`kubevela/product-catalog-gcp.yaml`](kubevela/product-catalog-gcp.yaml) |
| The bucket claim — three backings, two clouds | `../../platform/kubevela/components/` (`bucket-xp` / `bucket-ack` / `bucket-kcc`), [`../../platform/crossplane/s3/`](../../platform/crossplane/s3/), [`../../platform/kcc/`](../../platform/kcc/) |
| The swap — same claim, different backing/cloud | `diff kubevela/product-catalog.yaml kubevela/product-catalog-gcp.yaml` shows only the cloud-runtime delta |
| Extend the interface in Go | [`../../defkit/`](../../defkit/) |

> Build order followed: (1) `bucket` claim + Crossplane S3 (Track 1), (2) ACK S3
> behind the identical claim (Track 2), (3) KCC GCS behind the identical claim
> (Track 3, cross-cloud). The walkthrough's beat 5 shows the swap. Observability
> trait and the Defkit module are the remaining "looking ahead" pieces.
