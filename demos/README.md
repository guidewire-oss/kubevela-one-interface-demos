# demos/ — Runnable scenarios

> ⚠️ **Under construction** — this repository is a work in progress; content is incomplete and may change.

Each subdirectory is a **self-contained, runnable scenario** that strings the
shared building blocks (`../platform/`, `../apps/`, `../defkit/`) into a narrative
for a specific audience or event.

This is the **only** place event-specific content belongs. Keep the building
blocks evergreen; let demos compose them.

| Scenario | Audience | Status |
|----------|----------|--------|
| [`kubecon-in-2026/`](kubecon-in-2026/) | KubeCon India 2026 — "One Interface To Rule Them All" | 🚧 in progress |

## Adding a scenario

1. Create `demos/<event-or-topic>/`.
2. Add a `README.md` (what it shows, prerequisites, run steps) and a
   `walkthrough.md` (the spoken narrative mapped to commands).
3. Reuse `../platform/` and `../apps/` — only add files here for content unique
   to this scenario.
