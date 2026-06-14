#!/usr/bin/env python3
"""Cloud-neutral object-store abstraction for the Bucket Browser.

One interface (``ObjectStore``), two backends — AWS S3 and GCP Cloud Storage —
selected at runtime by ``STORAGE_PROVIDER``. The browser lists and reads objects and
never imports a cloud SDK directly, so the same UI serves a bucket on either cloud.

Environment variables
----------------------
STORAGE_PROVIDER            "aws" (default) or "gcp" — picks the backend.
BUCKET_NAME                 the bucket to browse (falls back to legacy S3_BUCKET_NAME).

AWS (STORAGE_PROVIDER=aws):
    AWS_REGION              region for the S3 client (default us-west-2).
    AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SHARED_CREDENTIALS_FILE
                            standard boto3 credential sources.

GCP (STORAGE_PROVIDER=gcp):
    GOOGLE_CLOUD_PROJECT    project id (falls back to GOOGLE_PROJECT_ID).
    GOOGLE_APPLICATION_CREDENTIALS
                            path to a service-account JSON key (read automatically).
"""
import os
from abc import ABC, abstractmethod


class StorageError(Exception):
    """Backend-agnostic storage failure (wraps boto3 / GCS provider errors)."""


class ObjectStore(ABC):
    """The single interface the browser depends on. Backends implement it per cloud."""

    #: short provider tag shown in the UI ("aws" / "gcp")
    provider: str = "unknown"
    #: the bucket being browsed
    bucket: str = ""
    #: human-readable location of the bucket (region / project)
    location: str = ""

    @abstractmethod
    def bucket_exists(self) -> bool:
        """True if the bucket is reachable with current credentials (readiness)."""

    @abstractmethod
    def list_objects(self, prefix: str = ""):
        """Return [{key, size, last_modified}] for every object (handles pagination)."""

    @abstractmethod
    def read_object(self, key: str):
        """Return {data, content_type, size, last_modified} for key, or None if absent."""


class S3ObjectStore(ObjectStore):
    """AWS S3 backend (boto3)."""

    provider = "aws"

    def __init__(self, bucket: str):
        self.bucket = bucket
        self.region = os.environ.get("AWS_REGION", "us-west-2")
        self.location = self.region
        self._client = None

    @property
    def client(self):
        # Lazy so app startup never blocks on credentials; readiness reports them.
        if self._client is None:
            import boto3
            self._client = boto3.client("s3", region_name=self.region)
        return self._client

    def bucket_exists(self):
        from botocore.exceptions import ClientError, NoCredentialsError
        try:
            self.client.head_bucket(Bucket=self.bucket)
            return True
        except (ClientError, NoCredentialsError):
            return False

    def list_objects(self, prefix=""):
        from botocore.exceptions import ClientError
        objects = []
        continuation_token = None
        try:
            while True:
                kwargs = {"Bucket": self.bucket}
                if prefix:
                    kwargs["Prefix"] = prefix
                if continuation_token:
                    kwargs["ContinuationToken"] = continuation_token
                response = self.client.list_objects_v2(**kwargs)
                for obj in response.get("Contents", []):
                    objects.append({
                        "key": obj["Key"],
                        "size": obj["Size"],
                        "last_modified": obj["LastModified"].strftime("%Y-%m-%d %H:%M:%S"),
                    })
                continuation_token = response.get("NextContinuationToken")
                if not continuation_token:
                    break
        except ClientError as e:
            raise StorageError(str(e)) from e
        return objects

    def read_object(self, key):
        from botocore.exceptions import ClientError
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=key)
            data = response["Body"].read()
            last_modified = response.get("LastModified")
            return {
                "data": data,
                "content_type": response.get("ContentType", "application/octet-stream"),
                "size": response.get("ContentLength", len(data)),
                "last_modified": last_modified.strftime("%Y-%m-%d %H:%M:%S") if last_modified else "",
            }
        except ClientError as e:
            code = e.response.get("Error", {}).get("Code", "")
            if code in ("NoSuchKey", "404"):
                return None
            raise StorageError(str(e)) from e


class GcsObjectStore(ObjectStore):
    """GCP Cloud Storage backend (google-cloud-storage)."""

    provider = "gcp"

    def __init__(self, bucket: str):
        self.bucket = bucket
        self.project = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get(
            "GOOGLE_PROJECT_ID", ""
        )
        self.location = self.project
        self._bucket_handle = None

    @property
    def _bucket_ref(self):
        # Lazy: the GCS client looks up credentials on construction, so defer it.
        if self._bucket_handle is None:
            from google.cloud import storage
            client = (
                storage.Client(project=self.project)
                if self.project
                else storage.Client()
            )
            self._bucket_handle = client.bucket(self.bucket)
        return self._bucket_handle

    def bucket_exists(self):
        try:
            return self._bucket_ref.exists()
        except Exception:
            return False

    def list_objects(self, prefix=""):
        from google.cloud.exceptions import GoogleCloudError
        try:
            objects = []
            for blob in self._bucket_ref.list_blobs(prefix=prefix or None):
                objects.append({
                    "key": blob.name,
                    "size": blob.size or 0,
                    "last_modified": blob.updated.strftime("%Y-%m-%d %H:%M:%S") if blob.updated else "",
                })
            return objects
        except GoogleCloudError as e:
            raise StorageError(str(e)) from e

    def read_object(self, key):
        from google.cloud.exceptions import GoogleCloudError
        try:
            # get_blob fetches metadata and returns None if the object is absent.
            blob = self._bucket_ref.get_blob(key)
            if blob is None:
                return None
            data = blob.download_as_bytes()
            return {
                "data": data,
                "content_type": blob.content_type or "application/octet-stream",
                "size": blob.size or len(data),
                "last_modified": blob.updated.strftime("%Y-%m-%d %H:%M:%S") if blob.updated else "",
            }
        except GoogleCloudError as e:
            raise StorageError(str(e)) from e


def build_object_store() -> ObjectStore:
    """Construct the ObjectStore for the configured provider.

    Reads STORAGE_PROVIDER and BUCKET_NAME (with a legacy S3_BUCKET_NAME fallback).
    Constructing the store does NOT open a client or contact the cloud — that is
    deferred to first use — so this is safe to call at import time.
    """
    provider = os.environ.get("STORAGE_PROVIDER", "aws").strip().lower()
    bucket = (
        os.environ.get("BUCKET_NAME")
        or os.environ.get("S3_BUCKET_NAME")
        or "product-catalog-images"
    )

    if provider in ("aws", "s3"):
        return S3ObjectStore(bucket)
    if provider in ("gcp", "gcs", "google"):
        return GcsObjectStore(bucket)
    raise StorageError(
        f"Unknown STORAGE_PROVIDER {provider!r}; use 'aws' or 'gcp'."
    )
