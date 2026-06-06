# KubeCon India 2026 — Walkthrough

The spoken narrative mapped to commands. Each section corresponds to a slide beat
from the session deck. Times are approximate for the 30-minute slot.

---

## 1. Setting the scene (slides: scale, infra size) — ~3 min

*No live commands.* Establish the scale that makes fragmentation painful: 120
clusters, 780 namespaces, ~88k services. The point: at this scale, every bit of
per-app complexity multiplies.

## 2. The problem: the complexity iceberg — ~4 min

Talk track: to deploy one service a developer had to master compute, networking,
observability, security, and IaC. Then the IaC ceiling — monolithic state files,
drift, the two-plane problem (kubectl for apps, Terraform for cloud).

*Optional cold-open:* show the volume of raw YAML/Terraform a single service used
to require, as a contrast to the single Application that replaces it.

## 3. The model: How vs What — ~4 min

Show the split without deploying yet:

```bash
# The How — platform team's building blocks
ls platform/traits platform/components platform/policies
vela def get high-availability        # the intent-based interface devs see

# The What — the developer's entire input
cat demos/kubecon-in-2026/kubevela/web-service.yaml
```

Land the point: the developer file has **no** HPA, PDB, affinity, or cloud detail.

## 4. One interface in action: deploy + auto-injected HA — ~6 min

```bash
vela up -f demos/kubecon-in-2026/kubevela/web-service.yaml
vela status web-service

# Everything the high-availability trait injected from `level: prod`:
kubectl get deploy,hpa,pdb -A
kubectl get pod -o wide               # anti-affinity / topology spread effect
```

Talk track: the developer asked for "production". The platform team's encoded
best practices supplied HPA + PDB + spread + anti-affinity. Change the policy
once, every app inherits it — governance runs itself.

## 5. One definition deploys code AND provisions cloud (S3) — ~5 min  🚧

*Pending the `bucket` component + S3 compositions.* This is the demo's core
proof. Headline resource is **S3**, shown across two backends from the SAME
developer Application.

**Track 1 — Crossplane + S3 (first target):**

```bash
# One Application: a web service that claims an S3 bucket.
vela up -f demos/kubecon-in-2026/kubevela/web-service-with-bucket.yaml   # 🚧 to be added
vela status web-service-with-bucket            # customStatus surfaces the bucket name/ARN
kubectl get bucket.s3 -A                        # Crossplane-provisioned S3 bucket
```

**Track 2 — ACK + S3 (second target), same developer YAML:**

```bash
# Switch the platform-side backend to ACK; the Application above is UNCHANGED.
vela status web-service-with-bucket
kubectl get buckets.s3.services.k8s.aws -A      # ACK-provisioned S3 bucket
```

Talk track: the developer file did not change one character between Track 1 and
Track 2. The platform team swapped Crossplane for ACK underneath. *That* is one
interface to rule them all — extends to KCC and beyond.

## 6. Looking ahead: Defkit (Go-native authoring) — ~4 min

```bash
# Scaffold a definition module in Go (KubeVela v1.11+)
vela def init-module --name my-platform --components webservice --traits scaler
```

Talk track: the interface itself is extensible. Platform teams author definitions
as normal Go packages with tests and IDE support; they compile to the identical
CUE the controller runs. See `../../defkit/`.

## 7. Close + Q&A — ~4 min

Recap: developers ship faster, SREs sleep better, governance is automatic. One
interface to rule them all.

---

## Reset between runs

```bash
vela delete web-service -y
# vela delete web-service-with-db -y   # when added
```
