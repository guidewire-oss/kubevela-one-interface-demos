# policies/ — PolicyDefinitions

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

App-wide governance that the platform team standardizes so it "runs itself":

- **topology** — which clusters/namespaces an app deploys to.
- **override** — per-environment parameter overrides (e.g. HA `level` per stage).
- **guardrails** — org-wide constraints applied uniformly.

Built-in KubeVela policies (`topology`, `override`, `shared-resource`) cover most
needs; add custom `PolicyDefinition` CUE here only when the built-ins fall short.

See the multi-environment workflow in [`../../../apps/`](../../../apps/) for how
`topology` + `override` policies drive a dev → staging → prod promotion from a
single Application.

> 🚧 Custom policy definitions land here as needed.
