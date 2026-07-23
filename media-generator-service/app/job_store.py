"""Redis-backed job store for async media generation.

Stores job metadata so the Arq worker can pick it up, and maintains a
job queue (list) for simple FIFO processing.

Task 2.1.2 / 2.2.2 of the async media generation migration plan.

Key layout:
  - ``gen:job:{job_id}`` — Redis hash storing job metadata (generation_id,
    generation_spec JSON, webhook_url, status, timestamps).
  - ``gen:jobs:queue``  — Redis sorted set of job_ids awaiting processing by Arq.
  - ``gen:jobs:dlq``    — Redis list of failed jobs (dead-letter queue).
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any

# pyrefly: ignore [missing-import]
import redis.asyncio as aioredis

from app.observability import log_job_lifecycle

logger = logging.getLogger("klass-media-generator.job_store")

# ─── Key prefixes ────────────────────────────────────────────────────────────

JOB_HASH_PREFIX = "gen:job:"
JOB_QUEUE_KEY = "gen:jobs:queue"
JOB_DLQ_KEY = "gen:jobs:dlq"


# ─── Public API ──────────────────────────────────────────────────────────────


async def create_job(
    redis: aioredis.Redis,
    job_id: str,
    generation_id: str,
    generation_spec: dict[str, Any],
    webhook_url: str,
) -> None:
    """Store a new job in Redis and push it to the processing queue.

    The job is stored as a hash at ``gen:job:{job_id}`` with the following
    fields:

    - ``generation_id``      — UUID of the media generation
    - ``generation_spec``    — JSON string of the full generation spec
    - ``webhook_url``        — URL the worker calls on completion
    - ``status``             — ``"pending"``
    - ``created_at``         — ISO 8601 timestamp
    - ``attempts``           — ``"0"``

    After storing the hash, the caller should enqueue the job using Arq's ``enqueue_job`` method.
    """
    key = f"{JOB_HASH_PREFIX}{job_id}"
    now = _now_iso()

    await redis.hset(key, mapping={
        "generation_id": generation_id,
        "generation_spec": json.dumps(generation_spec, separators=(",", ":")),
        "webhook_url": webhook_url,
        "status": "pending",
        "created_at": now,
        "attempts": "0",
    })

    logger.info(
        "job_store: created job %s for generation %s",
        job_id,
        generation_id,
    )

    # Sub-task 3.2.1: Structured lifecycle log for job creation
    log_job_lifecycle(
        "job.created",
        job_id=job_id,
        generation_id=generation_id,
        status="pending",
    )


async def get_job(redis: aioredis.Redis, job_id: str) -> dict[str, Any] | None:
    """Retrieve a job's metadata from Redis.

    Returns the decoded hash fields, or ``None`` if the job does not exist.
    The ``generation_spec`` field (JSON string) is parsed back into a dict.
    """
    key = f"{JOB_HASH_PREFIX}{job_id}"
    raw = await redis.hgetall(key)
    if not raw:
        return None

    # Normalise keys and values: arq's create_pool may return bytes keys/values
    # when ``decode_responses`` is not enabled.
    decoded: dict[str, Any] = {}
    for k, v in raw.items():
        str_key = k.decode() if isinstance(k, bytes) else k
        decoded[str_key] = v.decode() if isinstance(v, bytes) else v
    raw = decoded

    # ``generation_spec`` is stored as JSON — parse it back.
    if "generation_spec" in raw:
        raw["generation_spec"] = json.loads(raw["generation_spec"])

    # ``artifact_metadata`` is stored as JSON — parse it back.
    if "artifact_metadata" in raw:
        raw["artifact_metadata"] = json.loads(raw["artifact_metadata"])

    return raw


async def update_job_status(
    redis: aioredis.Redis,
    job_id: str,
    status: str,
    **extra_fields: str,
) -> None:
    """Update the status (and optional extra fields) of a job.

    Example::

        await update_job_status(redis, "job-1", "processing")
        await update_job_status(
            redis, "job-1", "completed",
            s3_object_key="materials/.../output.pdf",
            presigned_url="https://...",
        )
    """
    key = f"{JOB_HASH_PREFIX}{job_id}"
    mapping: dict[str, str] = {"status": status, "updated_at": _now_iso()}
    mapping.update(extra_fields)
    await redis.hset(key, mapping=mapping)


async def set_job_result(
    redis: aioredis.Redis,
    job_id: str,
    artifact_metadata: dict[str, Any],
    presigned_url: str,
    s3_object_key: str,
) -> None:
    """Mark a job as completed and store the artifact metadata + download URL.

    This is intended for the Arq worker to call after a successful generation.
    """
    await update_job_status(
        redis,
        job_id,
        "completed",
        artifact_metadata=json.dumps(artifact_metadata, separators=(",", ":")),
        presigned_url=presigned_url,
        s3_object_key=s3_object_key,
    )

    logger.info(
        "job_store: job %s completed (s3_key=%s)",
        job_id,
        s3_object_key,
    )

    # Sub-task 3.2.1: Structured lifecycle log for job completion
    log_job_lifecycle(
        "job.completed",
        job_id=job_id,
        status="completed",
        extra={"s3_object_key": s3_object_key},
    )


async def set_job_error(
    redis: aioredis.Redis,
    job_id: str,
    error_code: str,
    error_message: str,
) -> None:
    """Mark a job as failed and store the error details.

    This is intended for the Arq worker to call after a failed generation.
    """
    await update_job_status(
        redis,
        job_id,
        "failed",
        error_code=error_code,
        error_message=error_message,
    )

    logger.warning(
        "job_store: job %s failed (code=%s, msg=%s)",
        job_id,
        error_code,
        error_message,
    )

    # Sub-task 3.2.1: Structured lifecycle log for job failure
    log_job_lifecycle(
        "job.failed",
        job_id=job_id,
        status="failed",
        error_code=error_code,
        error_message=error_message,
    )



async def send_to_dlq(
    redis: aioredis.Redis,
    job_id: str,
    error_code: str,
    error_message: str,
    attempts: int,
) -> None:
    """Move a failed job to the dead-letter queue after exhausting retries.

    The job metadata is stored as a JSON string in the ``gen:jobs:dlq`` Redis
    list for manual inspection and potential re-queue by an admin.
    """
    dlq_entry = json.dumps({
        "job_id": job_id,
        "error_code": error_code,
        "error_message": error_message,
        "attempts": attempts,
        "moved_to_dlq_at": _now_iso(),
    }, separators=(",", ":"))

    await redis.lpush(JOB_DLQ_KEY, dlq_entry)

    logger.error(
        "job_store: job %s moved to DLQ after %d attempts "
        "(code=%s, msg=%s)",
        job_id,
        attempts,
        error_code,
        error_message,
    )

    # Sub-task 3.2.1: Structured lifecycle log for DLQ
    log_job_lifecycle(
        "job.dlq",
        job_id=job_id,
        status="dlq",
        error_code=error_code,
        error_message=error_message,
        extra={"attempts": attempts},
    )


# ─── Internal helpers ────────────────────────────────────────────────────────


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()
