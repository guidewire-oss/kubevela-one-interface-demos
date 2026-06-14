# KubeCon India 2026 — Walkthrough

The spoken narrative mapped to commands. Each section corresponds to a slide beat
from the session deck. Times are approximate for the 30-minute slot.

> **Run paths.** Each track is bootstrapped from its own setup folder:
> `aws-setup/` (Crossplane = Track 1, ACK = Track 2) and `gcp-setup/` (KCC = Track 3).
> Bootstrap the track(s) you'll demo **before** the talk; the live beats below are
> mostly status + the swap. The headline resource is an object-storage **bucket**,
> provisioned from the *same* developer Application across three backings and two clouds.

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
ls platform/kubevela/{components,traits,policies}
vela def get bucket                   # the intent-based bucket claim devs see
                                      #   params: name / region / versioning / projectName

# The What — the developer's entire input
cat demos/kubecon-in-2026/kubevela/product-catalog.yaml
```

Land the point: one file declares the app (a REST API **and** a read-only
`bucket-browser` web UI), its traits (autoscaling, security, resources), and a
**`bucket` claim** by name — no raw Kubernetes or cloud detail. The app code is
cloud-neutral too (`apps/*/storage.py` talks to an `ObjectStore`, not a cloud SDK).

## 4. One interface in action: deploy app + provision a bucket — ~6 min

Track 1 (Crossplane → AWS S3) was bootstrapped from `aws-setup/`:

```bash
# (prep) cd demos/kubecon-in-2026/aws-setup && ./init-with-xp.sh && ./setup-with-xp.sh
vela status product-catalog                  # customStatus surfaces the bucket name

# What the traits + override policies + bucket claim produced:
kubectl get deploy,hpa -A
kubectl get xs3buckets -A                    # the bucket claim (Crossplane composite)
kubectl get bucket.s3.aws.upbound.io -A      # the actual AWS S3 bucket(s): …-dev/-staging/-prod
```

Talk track: the developer asked for "production". The platform team's encoded best
practices supplied HPA + PDB + spread + anti-affinity. The multi-env workflow
promoted dev → staging → prod, and each env got its own globally-unique bucket
(`…-dev`/`-staging`/`-prod`) — all from one Application. Governance runs itself.

**See the objects — the bucket-browser UI.** The *same* Application also deploys a
read-only `bucket-browser` web UI (the `bucket-browser` component) pointed at the very
bucket the API writes to. Open it to show the objects the workflow's test products created:

```bash
kubectl -n dev port-forward svc/bucket-browser 8080:8080
# open http://localhost:8080  → lists the bucket's objects; click one to view its contents
```

## 5. One claim, three backings, two clouds — ~6 min

The core proof: the developer's `bucket` claim is **byte-for-byte identical** no
matter who provisions it — or on which cloud. Only the platform-side backing changes
(install exactly one; all three register a ComponentDefinition named `bucket`).

**Same cloud, different backend — Crossplane → ACK (both AWS S3):**

```bash
# Swap the backing on the cluster; the developer Application is UNCHANGED.
vela def apply platform/kubevela/components/bucket-ack.cue
vela up -f demos/kubecon-in-2026/kubevela/product-catalog.yaml
kubectl get buckets.s3.services.k8s.aws -A   # now an ACK-provisioned S3 bucket
```

**Cross-cloud — AWS → GCP (KCC, GCS).** The killer visual is the diff: the `bucket`
claim doesn't change; only the app's cloud-runtime block (provider + creds mount) does:

```bash
diff demos/kubecon-in-2026/kubevela/product-catalog.yaml \
     demos/kubecon-in-2026/kubevela/product-catalog-gcp.yaml
#  → STORAGE_PROVIDER aws→gcp, aws-credentials→gcp-key mount, AWS_REGION→GOOGLE_CLOUD_PROJECT
#  → the `bucket` claim block is IDENTICAL

# Track 3 was bootstrapped from gcp-setup/ (separate cluster):
#   cd demos/kubecon-in-2026/gcp-setup && ./init-with-kcc.sh && ./setup-with-kcc.sh
vela status product-catalog
kubectl get storagebucket -A                 # a KCC-provisioned GCS bucket, same claim
```

```bash
# Same browser, now showing GCS objects — open it on the GCP cluster:
kubectl -n dev port-forward svc/bucket-browser 8080:8080   # http://localhost:8080
```

Talk track: the developer file's *claim* did not change one character — across two
AWS backends **and** a different cloud. `bucket-kcc.cue` even translates the claim's
AWS-style `region` (`us-west-2`) to a valid GCP `location` (`us-west1`) so the dev
YAML stays identical. The **same `bucket-browser` image and UI** rides along unchanged
— it just lists S3 objects on one cluster and GCS objects on the other. That is one
interface to rule them all.

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
interface to rule them all — across backends and across clouds.

---

## Reset between runs

```bash
# ACK track: empty the S3 buckets first (ACK has no force-destroy), then delete.
demos/kubecon-in-2026/aws-setup/teardown-with-ack.sh

# Crossplane and KCC tracks tear down cleanly on their own (forceDestroy / force-destroy):
vela delete product-catalog -y

# Then delete the local cluster + registry:
demos/kubecon-in-2026/cleanup.sh
```
