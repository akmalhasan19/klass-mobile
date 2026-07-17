"""S3/R2 object storage client for async media generation artifacts.

Task 2.4.1 / 2.4.3 of the async media generation migration plan.

Provides:
- ``upload_artifact()`` — upload a local artifact file to S3/R2 using
  streaming ``upload_fileobj``, then generate a presigned download URL.
- ``get_storage_client()`` — creates a ``boto3`` S3 client configured for
  Cloudflare R2 (S3-compatible) from app ``Settings``.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import boto3
from boto3.s3.transfer import TransferConfig
from botocore.config import Config as BotoConfig

from app.settings import Settings

logger = logging.getLogger("klass-media-generator.storage")

# ─── Constants ───────────────────────────────────────────────────────────────

PRESIGNED_URL_TTL_SECONDS = 3600
"""Default TTL for presigned download URLs (1 hour)."""

OBJECT_KEY_TEMPLATE = "{prefix}/{generation_id}/{filename}"
"""S3 object key pattern for generated artifacts.

Examples:
    materials/550e8400-e29b-41d4-a716-446655440000/output.pdf
    previews/550e8400-e29b-41d4-a716-446655440000/preview.html
"""

# ─── Multipart upload tuning ─────────────────────────────────────────────────

MULTIPART_THRESHOLD_BYTES = 50 * 1024 * 1024
"""Files larger than this (50 MB) use multipart upload."""

MULTIPART_CHUNK_SIZE_BYTES = 25 * 1024 * 1024
"""Each multipart chunk is 25 MB."""

MAX_UPLOAD_CONCURRENCY = 4
"""Maximum parallel threads for multipart upload."""


# ─── Client factory ──────────────────────────────────────────────────────────


def get_storage_client(settings: Settings) -> boto3.client:
    """Create a boto3 S3 client configured for Cloudflare R2.

    Uses the S3-compatible endpoint, access key, and secret from the app
    settings.  The client is configured with:
    - ``signature_version = 's3v4'`` (required for R2 presigned URLs).
    - ``addressing_style = 'virtual'``.
    - 10s connect / 30s read timeouts.
    """
    # Path-style addressing works with both Cloudflare R2 and MinIO (E2E).
    # Virtual-hosted style breaks MinIO when the endpoint is a bare hostname
    # (e.g. http://minio:9000 → klass-media.minio which does not resolve).
    return boto3.client(
        "s3",
        endpoint_url=settings.r2_endpoint,
        aws_access_key_id=settings.r2_access_key_id,
        aws_secret_access_key=settings.r2_secret_access_key,
        region_name="auto",
        config=BotoConfig(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            connect_timeout=10,
            read_timeout=30,
            retries={"max_attempts": 3, "mode": "adaptive"},
        ),
    )


# ─── Upload + presigned URL ──────────────────────────────────────────────────


def upload_artifact(
    settings: Settings,
    local_path: str,
    generation_id: str,
    filename: str,
    prefix: str = "materials",
) -> tuple[str, str]:
    """Upload a generated artifact to S3/R2 and return (presigned_url, s3_key).

    This is a **synchronous** function designed to be called from a thread
    pool (``run_in_executor``) in the async worker.

    Uses ``boto3.s3.transfer.TransferConfig`` with explicit multipart
    settings for large files (> 50 MB):
    - Multipart threshold: 50 MB
    - Chunk size: 25 MB
    - Max concurrency: 4 threads

    Args:
        settings: App settings with R2 credentials.
        local_path: Local filesystem path to the generated artifact.
        generation_id: UUID of the media generation (used in the object key).
        filename: Desired filename in storage (e.g. ``"output.pdf"``).

    Returns:
        A tuple of ``(presigned_url, s3_object_key)``.

    Raises:
        FileNotFoundError: If ``local_path`` does not exist.
        botocore.exceptions.ClientError: If the S3 upload fails.
    """
    path = Path(local_path)
    if not path.is_file():
        raise FileNotFoundError(f"Artifact not found at {local_path}")

    s3_object_key = OBJECT_KEY_TEMPLATE.format(
        prefix=prefix,
        generation_id=generation_id,
        filename=filename,
    )

    client = get_storage_client(settings)
    bucket = settings.r2_bucket_name

    file_size = path.stat().st_size
    transfer_config = TransferConfig(
        multipart_threshold=MULTIPART_THRESHOLD_BYTES,
        multipart_chunksize=MULTIPART_CHUNK_SIZE_BYTES,
        max_concurrency=MAX_UPLOAD_CONCURRENCY,
        use_threads=file_size > MULTIPART_THRESHOLD_BYTES,
    )

    client.upload_file(
        str(path),
        bucket,
        s3_object_key,
        Config=transfer_config,
    )

    logger.info(
        "storage: uploaded %s to s3://%s/%s (%d bytes, multipart=%s)",
        local_path,
        bucket,
        s3_object_key,
        file_size,
        file_size > MULTIPART_THRESHOLD_BYTES,
    )

    presigned_url = client.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": s3_object_key},
        ExpiresIn=PRESIGNED_URL_TTL_SECONDS,
    )

    logger.info(
        "storage: presigned URL generated for s3://%s/%s (ttl=%ds)",
        bucket,
        s3_object_key,
        PRESIGNED_URL_TTL_SECONDS,
    )

    return presigned_url, s3_object_key
