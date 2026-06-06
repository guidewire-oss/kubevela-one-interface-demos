# KubeVela One Interface — Demos

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

> **One Interface To Rule Them All** — taming Kubernetes complexity with KubeVela
> and the Open Application Model (OAM).

A collection of demos built around a single theme: using KubeVela + OAM as **one
interface that tames the complexity of Kubernetes**.

- **[`demos/`](demos/)** — the demos themselves; each is a self-contained folder.
- **[`platform/`](platform/)** — reusable building blocks (Components, Traits,
  Policies, compositions) shared across demos.
- **[`apps/`](apps/)** — application source code, shared across demos.

## The story this repo tells

Platform fragmentation is a silent productivity killer. To ship one service a
developer ends up mastering compute, networking, observability, security, and
infrastructure-as-code — the **complexity iceberg**. KubeVela + OAM collapses
that into a single interface:

| Role | Concern | Lives in |
|------|---------|----------|
| **Platform team** — *the How* | Defines reusable, secure building blocks (Components, Traits, Policies) and cloud compositions that encapsulate best practices and governance. | [`platform/`](platform/) |
| **Application developer** — *the What* | Declares needs in one simple YAML. Claims a database, gets autoscaling, observability, and compliance — without knowing the implementation. | [`demos/<demo>/kubevela/`](demos/) |

One workload definition deploys application code **and** provisions the cloud
resources it depends on. Reusable traits auto-inject observability, compliance,
and HA so developers never hand-write that boilerplate.

## Demos

### 1. KubeCon India 2026 — Mumbai
**Location:** [`demos/kubecon-in-2026/`](demos/kubecon-in-2026/)

**Status:** Under construction

**See:** [`demos/kubecon-in-2026/README.md`](demos/kubecon-in-2026/README.md) for complete documentation

## Repository layout

```
kubevela-one-interface-demos/
├── platform/          # "The How" — platform-team building blocks
│   ├── components/    #   ComponentDefinitions (CUE)
│   ├── traits/        #   TraitDefinitions — auto-inject HA, observability, compliance
│   ├── policies/      #   PolicyDefinitions — governance, topology, overrides
│   └── compositions/  #   S3 backends — Crossplane (track 1) then ACK (track 2)
├── apps/              # Application source code (one folder per app)
├── demos/             # Runnable, self-contained scenarios (one per event/topic)
│   └── kubecon-in-2026/   #   KubeCon India 2026 demo — runs per-demo:
│       ├── config.yaml #     cluster/crossplane settings for this demo
│       ├── kubevela/   #     this demo's KubeVela Application(s)
│       ├── init.sh     #     Bootstrap a local cluster + KubeVela + Crossplane
│       └── setup.sh    #     Apply platform blocks + deploy the sample app
├── defkit/            # Go-native X-Definition authoring (KubeVela v1.11+)
└── scripts/           # Shared helpers used by each demo's init/setup
```

Each demo owns its `init.sh`, `setup.sh`, `config.yaml`, and `kubevela/`; the
platform building blocks and apps are shared at the repo root.

## Additional Resources

- [KubeVela Documentation](https://kubevela.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [OAM Specification](https://oam.dev/)
- [KubeVela GitHub](https://github.com/kubevela/kubevela)
- [Slack channel](https://cloud-native.slack.com/archives/C01BLQ3HTJA)
- [KubeVela Roadmap](https://github.com/kubevela/kubevela.github.io/blob/main/docs/roadmap/README.md)
- [DeepWiki MCP Server](https://docs.devin.ai/work-with-devin/deepwiki-mcp)
- [DeepWiki KubeVela AI Documentation and AI Chat](https://deepwiki.com/kubevela/kubevela)
