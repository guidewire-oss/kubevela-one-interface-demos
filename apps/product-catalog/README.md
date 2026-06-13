# Product Catalog API

A simple Flask-based REST API that stores product metadata and images in an
**object-storage bucket** — on **either AWS S3 or GCP Cloud Storage**, chosen at
runtime. The API code is cloud-neutral: it talks to the `ObjectStore` abstraction
in [`storage.py`](storage.py), never to a cloud SDK directly. Swapping clouds is a
config change (`STORAGE_PROVIDER`), not a code change — the "one interface" promise
applied to the application tier.

## Features

- **GET /health** - Health check endpoint
- **GET /ready** - Readiness check (verifies the storage bucket is accessible)
- **GET /products** - List all products
- **POST /products** - Create a new product with optional image upload
- **GET /products/{id}** - Get a specific product with a signed URL for its image
- **DELETE /products/{id}** - Delete a product and its stored image

## How the cloud-neutral storage works

```
            ┌─────────────┐
 request ──▶│  Flask API  │  (app.py — no cloud SDK imports)
            └──────┬──────┘
                   │  ObjectStore interface (storage.py)
        ┌──────────┴──────────┐
        ▼                     ▼
 ┌─────────────┐       ┌─────────────┐
 │ S3ObjectStore│      │GcsObjectStore│   ← chosen by STORAGE_PROVIDER
 │   (boto3)    │      │(google-cloud)│
 └──────┬───────┘      └──────┬───────┘
        ▼                     ▼
   AWS S3 bucket         GCP GCS bucket
```

`STORAGE_PROVIDER=aws` → S3 (boto3); `STORAGE_PROVIDER=gcp` → Cloud Storage
(google-cloud-storage). Both SDKs ship in the image; only the env var decides which
is used. Object keys, the REST contract, and every handler are identical across
clouds.

## Environment Variables

| Variable | Applies to | Purpose | Default |
|----------|-----------|---------|---------|
| `STORAGE_PROVIDER` | both | `aws` or `gcp` — selects the backend | `aws` |
| `BUCKET_NAME` | both | the bucket to use (cloud-neutral) | `product-catalog-images` |
| `PORT` | both | port to listen on | `8080` |
| `AWS_REGION` | aws | S3 client region | `us-west-2` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SHARED_CREDENTIALS_FILE` | aws | boto3 credentials | — |
| `GOOGLE_CLOUD_PROJECT` | gcp | GCP project id (falls back to `GOOGLE_PROJECT_ID`) | — |
| `GOOGLE_APPLICATION_CREDENTIALS` | gcp | path to a service-account JSON key (also needed for signed URLs) | — |

> `BUCKET_NAME` is the unified, cloud-neutral name. For backward compatibility the
> app still reads the legacy `S3_BUCKET_NAME` if `BUCKET_NAME` is unset.

## Local Development

### AWS S3

```bash
pip install -r requirements.txt

export STORAGE_PROVIDER=aws
export BUCKET_NAME=my-product-images
export AWS_REGION=us-west-2
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key

python app.py
./test_api.sh
```

### GCP Cloud Storage

```bash
pip install -r requirements.txt

export STORAGE_PROVIDER=gcp
export BUCKET_NAME=my-product-images
export GOOGLE_CLOUD_PROJECT=my-gcp-project
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

python app.py
./test_api.sh
```

The REST contract (and `test_api.sh`) is the same regardless of provider.

## Build & push the image (for the demo)

Use the build script — it builds from this folder's `Dockerfile`, pushes to the
local k3d registry, and prints the in-cluster image reference to drop into the
KubeVela `Application`:

```bash
./build-image.sh
#  → pushes  localhost:5000/product-catalog:v1.0.0
#  → use     k3d-registry.localhost:5000/product-catalog:v1.0.0  in the Application

# Optional overrides:
#   ./build-image.sh [image_name] [tag] [host_registry] [incluster_registry]
```

(The k3d cluster + local registry are created by the demo's track `init-*` script —
e.g. `demos/kubecon-in-2026/aws-setup/init-with-xp.sh` or `gcp-setup/init-with-kcc.sh`.
Each track's `setup-*` script runs this build for you.)

### Run standalone (without Kubernetes)

```bash
docker build -t product-catalog:v1.0.0 .

# AWS
docker run -p 8080:8080 \
  -e STORAGE_PROVIDER=aws -e BUCKET_NAME=your-bucket -e AWS_REGION=us-west-2 \
  -e AWS_ACCESS_KEY_ID=your_access_key -e AWS_SECRET_ACCESS_KEY=your_secret_key \
  product-catalog:v1.0.0

# GCP
docker run -p 8080:8080 \
  -e STORAGE_PROVIDER=gcp -e BUCKET_NAME=your-bucket \
  -e GOOGLE_CLOUD_PROJECT=your-project \
  -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/key.json \
  -v /path/to/key.json:/secrets/key.json:ro \
  product-catalog:v1.0.0
```

## Security Features

- Non-root user in Docker container
- Read-only root filesystem compatible
- Signed URLs for secure, time-limited object access (S3 presigned / GCS v4 signed)
- IAM role-based authentication when available (IRSA on AWS, Workload Identity on GCP)
