# demos/ — Runnable scenarios

Each subdirectory is a **self-contained, runnable scenario** that strings the
shared building blocks (`../platform/`, `../apps/`, `../defkit/`) into a narrative
for a specific audience or event.

This is the **only** place event-specific content belongs. Keep the building
blocks evergreen; let demos compose them.

| Scenario | Audience | Tracks |
|----------|----------|--------|
| [`kubecon-in-2026/`](kubecon-in-2026/) | KubeCon India 2026 — "One Interface To Rule Them All" | AWS (Crossplane / ACK) + GCP (KCC) |

## Per-track setup folders

A scenario can demonstrate the *same* developer Application against several
platform backings. `kubecon-in-2026/` keeps each cloud's bootstrap self-contained
in its own folder — `aws-setup/` (Crossplane + ACK) and `gcp-setup/` (KCC) — each
holding its `init-*`/`setup-*` scripts, **matching `00_init-*`/`01_setup-*` Jupyter
notebooks** (the notebook form of those scripts, reusing the same `scripts/` helpers),
`config.yaml`, and credentials. The shared KubeVela Application(s) live in the
scenario's `kubevela/` folder.

## Adding a scenario

1. Create `demos/<event-or-topic>/`.
2. Add a `README.md` (what it shows, prerequisites, run steps) and a
   `walkthrough.md` (the spoken narrative mapped to commands).
3. Reuse `../platform/` and `../apps/` — only add files here for content unique
   to this scenario.
