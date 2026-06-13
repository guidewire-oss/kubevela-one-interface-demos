# KubeVela One Interface — Demos

> **One Interface To Rule Them All** — taming Kubernetes complexity with KubeVela
> and the Open Application Model (OAM).

A collection of demos built around a single theme: using KubeVela + OAM as **one
interface that tames the complexity of Kubernetes** — including provisioning cloud
resources across multiple clouds from the *same* developer-facing declaration.

- **[`demos/`](demos/)** — the demos themselves; each is a self-contained folder.
- **[`platform/`](platform/)** — reusable building blocks (Components, Traits,
  Policies) and cloud assets (Crossplane, Config Connector) shared across demos.
- **[`apps/`](apps/)** — application source code (cloud-neutral), shared across demos.

## The story this repo tells

Platform fragmentation is a silent productivity killer. To ship one service a
developer ends up mastering compute, networking, observability, security, and
infrastructure-as-code — the **complexity iceberg**. KubeVela + OAM collapses
that into a single interface:

| Role | Concern | Lives in |
|------|---------|----------|
| **Platform team** — *the How* | Defines reusable, secure building blocks (Components, Traits, Policies) and cloud compositions that encapsulate best practices and governance. | [`platform/`](platform/) |
| **Application developer** — *the What* | Declares needs in one simple YAML. Claims a bucket, gets autoscaling, observability, and compliance — without knowing the implementation. | [`demos/<demo>/kubevela/`](demos/) |

One workload definition deploys application code **and** provisions the cloud
resources it depends on. Reusable traits auto-inject observability, compliance,
and HA so developers never hand-write that boilerplate.

## One interface, three backings, two clouds

The headline resource is an object-storage **bucket**. The developer's `bucket`
claim is **identical** no matter how — or where — it is provisioned. Only the
platform-side backing changes:

| Track | Backing | Cloud | Resource | Platform assets |
|-------|---------|-------|----------|-----------------|
| **1** | Crossplane | AWS | S3 | [`platform/crossplane/`](platform/crossplane/) + `bucket-xp.cue` |
| **2** | AWS Controllers for Kubernetes (ACK) | AWS | S3 | `bucket-ack.cue` |
| **3** | Google Config Connector (KCC) | GCP | GCS | [`platform/kcc/`](platform/kcc/) + `bucket-kcc.cue` |

All three register a ComponentDefinition named `bucket` with the **same
parameters** (`name` / `region` / `versioning` / `projectName`). Install exactly
one backing; the developer Application never changes. Track 3 is the strongest
expression of the promise — the same claim crosses not just backends but clouds
(AWS → GCP). The application tier is cloud-neutral too: the sample app talks to an
`ObjectStore` abstraction (S3 or GCS, chosen by `STORAGE_PROVIDER`), never to a
cloud SDK directly.

## Demos

### 1. KubeCon India 2026 — Mumbai

**Location:** [`demos/kubecon-in-2026/`](demos/kubecon-in-2026/)

**Tracks:** AWS (Crossplane / ACK) and GCP (KCC), each with its own setup folder.

**See:** [`demos/kubecon-in-2026/README.md`](demos/kubecon-in-2026/README.md) for
complete documentation and [`walkthrough.md`](demos/kubecon-in-2026/walkthrough.md)
for the spoken narrative.

## Repository layout

```
kubevela-one-interface-demos/
├── platform/              # "The How" — platform-team building blocks
│   ├── kubevela/          #   KubeVela X-Definitions:
│   │   ├── components/    #     bucket-xp / bucket-ack / bucket-kcc (the bucket claim, 3 backings)
│   │   │   └── example/   #       a minimal Application that just claims a bucket
│   │   ├── traits/        #     high-availability, s3-versioning
│   │   └── policies/      #     governance, topology, overrides
│   ├── crossplane/        #   Crossplane assets (AWS S3): function, providers, ProviderConfigs, S3 XRD+Composition
│   └── kcc/               #   Config Connector assets (GCP GCS): ConfigConnector + StorageBucket example
├── apps/                  # Application source code, cloud-neutral (one folder per app)
│   └── product-catalog/   #   Flask API; storage.py abstracts S3 vs GCS
├── demos/                 # Runnable, self-contained scenarios (one per event/topic)
│   └── kubecon-in-2026/
│       ├── kubevela/      #     product-catalog.yaml (AWS) + product-catalog-gcp.yaml (GCP)
│       ├── aws-setup/     #     AWS tracks — init/setup-with-xp (Crossplane), -with-ack (ACK), teardown-with-ack
│       ├── gcp-setup/     #     GCP track — init/setup-with-kcc (KCC)
│       ├── cleanup.sh     #     delete the local cluster + registry
│       └── walkthrough.md #     slide beats mapped to commands
├── defkit/                # Go-native X-Definition authoring (KubeVela v1.11+)
└── scripts/               # Shared bootstrap helpers (see scripts/index.md)
```

Each track owns its `init-*`/`setup-*` scripts + local state under its own setup
folder (`aws-setup/` or `gcp-setup/`); the platform building blocks, the apps, and
the shared `scripts/` helpers live at the repo root.

## Additional Resources

- [KubeVela Documentation](https://kubevela.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [AWS Controllers for Kubernetes (ACK)](https://aws-controllers-k8s.github.io/community/)
- [Google Config Connector (KCC)](https://cloud.google.com/config-connector/docs/overview)
- [OAM Specification](https://oam.dev/)
- [KubeVela GitHub](https://github.com/kubevela/kubevela)
- [Slack channel](https://cloud-native.slack.com/archives/C01BLQ3HTJA)
- [DeepWiki KubeVela AI Documentation and AI Chat](https://deepwiki.com/kubevela/kubevela)
