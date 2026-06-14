# apps/ — Application source code

This directory holds the **source code** for the demo applications — one folder
per app. Each app is a normal, self-contained project (its own `Dockerfile`,
dependencies, and `README.md`) that gets built and pushed to the local registry
so a demo can deploy it.

Apps are written **cloud-neutral**: storage, messaging, etc. go through small
abstractions selected at runtime by env var, so the *same* image runs on AWS or
GCP. That mirrors the "one interface" promise at the application tier.

The **KubeVela `Application` that deploys an app is not here** — it lives with the
demo that uses it, under `demos/<demo>/kubevela/`. That keeps the source reusable
across demos while each demo owns the manifest that wires the app together with
the platform building blocks for its scenario.

```
apps/
└── <app-name>/          # one folder per application (source code)
    ├── Dockerfile
    ├── README.md
    └── …                # app sources, tests, deps

demos/<demo>/kubevela/   # the KubeVela Application(s) that deploy the app(s)
```

## Apps

| App | What it is |
|-----|------------|
| [`product-catalog/`](product-catalog/) | A Flask REST API that stores product images in an object-storage bucket — **AWS S3 or GCP GCS**, chosen at runtime by `STORAGE_PROVIDER` via an `ObjectStore` abstraction (`/products`, `/health`, `/ready`). The headline app for the one-interface bucket demo. |
| [`bucket-browser/`](bucket-browser/) | A read-only Flask **web UI** that browses a bucket's objects and renders their contents — same cloud-neutral `ObjectStore` (S3 or GCS). Deploy it next to product-catalog to *see* the objects that app wrote, on either cloud. |

## Adding an app

1. Create `apps/<app-name>/` with the source (`Dockerfile`, code, `README.md`).
2. Build + push it to the local registry (`k3d-registry.localhost:5000/<app>:<tag>`).
3. Write the KubeVela `Application` that deploys it under the demo that uses it,
   in `demos/<demo>/kubevela/` — declaring *needs* (components + traits) so the
   platform building blocks in [`../platform/`](../platform/) supply the
   implementation (HA, observability, cloud provisioning).
