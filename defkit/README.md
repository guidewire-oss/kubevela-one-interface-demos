# defkit/ — Go-native X-Definition authoring

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

[Defkit](https://kubevela.io/) is a Go SDK for authoring KubeVela X-Definitions
(Component, Trait, Policy, WorkflowStep) in Go instead of hand-writing CUE.
Available from **KubeVela v1.11.0-alpha.2**.

Why it matters for the "one interface" story — it lowers the barrier for the
*platform team* to extend the interface:

- **Identical CUE** — compiles to the exact CUE the controller already
  understands. Zero runtime change.
- **Native Go** — definitions are normal Go packages: `go get`, `go test`,
  semver, full IDE support, refactoring.
- **CLI scaffold** — generate a whole module in one command.

## Scaffold a module

```bash
vela def init-module --name my-platform \
  --components webservice,worker \
  --traits scaler

my-platform/
├── module.yaml        # metadata + hooks + placement
├── components/        # ComponentDefinitions (webservice.go ...)
├── traits/            # TraitDefinitions (env.go, scaler.go ...)
└── workflowsteps/     # WorkflowStepDefinitions
```

## How this fits the repo

The canonical definitions in [`../platform/`](../platform/) are CUE. This
directory demonstrates the **Go-native authoring workflow** — e.g. re-authoring
the `high-availability` trait in Go and showing it compiles to the same CUE. Use
it as the "looking ahead / extensibility" beat, not as a replacement for the CUE
definitions.

> 🚧 Add a worked Defkit module here. Verify the exact CLI flags and API against
> the KubeVela source (v1.11+) via the deepwiki MCP before documenting — this is
> a new, fast-moving feature.
