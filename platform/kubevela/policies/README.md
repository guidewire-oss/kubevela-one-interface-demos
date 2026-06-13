# policies/ — PolicyDefinitions

App-wide governance that the platform team standardizes so it "runs itself":

- **topology** — which clusters/namespaces an app deploys to.
- **override** — per-environment parameter overrides (e.g. HA `level` per stage).
- **guardrails** — org-wide constraints applied uniformly.

Built-in KubeVela policies (`topology`, `override`, `shared-resource`) cover most
needs; add custom `PolicyDefinition` CUE here only when the built-ins fall short.

See the multi-environment workflow in the demo Application
[`../../../demos/kubecon-in-2026/kubevela/product-catalog.yaml`](../../../demos/kubecon-in-2026/kubevela/product-catalog.yaml)
for how `topology` + `override` policies drive a dev → staging → prod promotion
from a single Application — including per-environment `override`s that set the
bucket name and the cloud-runtime env (`STORAGE_PROVIDER`, credentials) the app pod
needs.

Custom `PolicyDefinition` CUE lands here as needed.
