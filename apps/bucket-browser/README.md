# Bucket Browser

A small Flask web UI that **browses an object-storage bucket** — lists its objects
and renders their contents in the browser. The bucket can be **AWS S3 or GCP Cloud
Storage**, chosen at runtime: the app talks to the `ObjectStore` abstraction in
[`storage.py`](storage.py), never to a cloud SDK directly. The read-only browser
counterpart to [`../product-catalog/`](../product-catalog/).

It's a great visual for the "one interface" demo: deploy it next to the
product-catalog app and *see* the objects that app wrote — to S3 or GCS — with the
same image, switching only `STORAGE_PROVIDER`.

## Endpoints

- **GET /** — list the bucket's objects (provider / bucket / location header + table)
- **GET /view/{key}** — render a single object's contents (UTF-8; binary is summarized)
- **GET /health** — liveness
- **GET /ready** — readiness (verifies the bucket is reachable)

## Environment Variables

| Variable | Applies to | Purpose | Default |
|----------|-----------|---------|---------|
| `STORAGE_PROVIDER` | both | `aws` or `gcp` — selects the backend | `aws` |
| `BUCKET_NAME` | both | the bucket to browse (cloud-neutral; legacy `S3_BUCKET_NAME` honored) | `product-catalog-images` |
| `PORT` | both | port to listen on | `8080` |
| `AWS_REGION` | aws | S3 client region | `us-west-2` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SHARED_CREDENTIALS_FILE` | aws | boto3 credentials | — |
| `GOOGLE_CLOUD_PROJECT` | gcp | GCP project id (falls back to `GOOGLE_PROJECT_ID`) | — |
| `GOOGLE_APPLICATION_CREDENTIALS` | gcp | path to a service-account JSON key | — |

## Local Development

```bash
pip install -r requirements.txt

# AWS
export STORAGE_PROVIDER=aws BUCKET_NAME=my-bucket AWS_REGION=us-west-2
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
python app.py     # → http://localhost:8080

# GCP
export STORAGE_PROVIDER=gcp BUCKET_NAME=my-bucket GOOGLE_CLOUD_PROJECT=my-project
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
python app.py
```

## Build & push the image (for the demo)

```bash
./build-image.sh
#  → pushes  localhost:5000/bucket-browser:v1.0.0
#  → use     k3d-registry.localhost:5000/bucket-browser:v1.0.0  in the Application

# Optional overrides:
#   ./build-image.sh [image_name] [tag] [host_registry] [incluster_registry]
```

## Use it in a KubeVela Application

Point a `webservice` component at the image and give it the same `STORAGE_PROVIDER` /
`BUCKET_NAME` + credentials the product-catalog app uses, so it browses the same
bucket the `bucket` claim provisioned. On AWS mount the `aws-credentials` secret and
set `AWS_SHARED_CREDENTIALS_FILE`; on GCP mount the `gcp-key` secret and set
`GOOGLE_APPLICATION_CREDENTIALS` — exactly like
[`demos/kubecon-in-2026/kubevela/product-catalog{,-gcp}.yaml`](../../demos/kubecon-in-2026/kubevela/).
