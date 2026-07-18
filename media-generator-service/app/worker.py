"""Arq background worker for async media generation.

Task 2.3.2 / 2.3.3 of the async media generation migration plan.

Flow:
1. Arq picks up a ``process_generation_job`` from the Redis list.
2. Worker retrieves the job metadata (generation_spec, webhook_url) from Redis.
3. Worker generates the artifact using the existing generator registry.
4. Worker uploads the artifact to S3/R2 and generates a presigned URL.
5. Worker stores the result in Redis (``set_job_result``).
6. Worker sends a webhook to the Rust Gateway to notify completion.
7. On failure, stores error in Redis and sends failure webhook.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from arq.connections import RedisSettings

from app.document_model import build_render_document
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.html_template import HtmlTemplateEngine
from app.generators.registry import GeneratorRegistry
from app.job_store import get_job, send_to_dlq, set_job_error, set_job_result, update_job_status
from app.models import GenerateRequest, GenerationSpec, RequestContracts
from app.observability import log_job_lifecycle, metrics, trace_span
from app.settings import get_settings
from app.storage import upload_artifact
from app.preview.preview_handler import store_preview_html
from app.webhook_sender import MAX_WEBHOOK_ATTEMPTS, send_webhook_with_retry

logger = logging.getLogger("klass-media-generator.worker")

# Module-level registry — initialised once at worker startup.
_registry: GeneratorRegistry | None = None
_template_registry: Any = None


async def startup(ctx: dict[str, Any]) -> None:
    """Arq startup hook — initialises the generator registry and reconfigures Redis pool."""
    global _registry, _template_registry
    from app.templates.registry import TemplateRegistry
    import app.templates as templates_pkg
    from pathlib import Path

    _template_registry = TemplateRegistry()
    templates_dir = Path(templates_pkg.__file__).resolve().parent
    _template_registry.load_templates(templates_dir)

    _registry = GeneratorRegistry(template_registry=_template_registry)

    settings = get_settings()

    # Reconfigure the worker's Redis connection pool with tuning parameters.
    # arq creates the connection internally via RedisSettings; we replace the
    # connection pool with one that has proper max_connections and timeouts.
    redis = ctx.get("redis")
    if redis is not None:
        import redis.asyncio as aioredis
        new_pool = aioredis.ConnectionPool.from_url(
            settings.redis_url,
            max_connections=settings.redis_max_connections,
            socket_connect_timeout=settings.redis_socket_connect_timeout_seconds,
            socket_timeout=settings.redis_socket_timeout_seconds,
            health_check_interval=settings.redis_health_check_interval_seconds,
            decode_responses=False,
        )
        await redis.connection_pool.disconnect()
        redis.connection_pool = new_pool
        logger.info(
            "Worker Redis pool reconfigured (max_connections=%d, socket_timeout=%ds)",
            settings.redis_max_connections,
            settings.redis_socket_timeout_seconds,
        )

    logger.info(
        "Arq worker started, generator registry initialised "
        "(concurrency=%d, auto=%s, max=%d, memory_limit=%dMB, "
        "job_timeout=%ds)",
        settings.worker_concurrency,
        settings.worker_concurrency_auto,
        settings.worker_max_concurrency,
        settings.worker_memory_limit_mb,
        settings.worker_job_timeout_seconds,
    )


async def shutdown(ctx: dict[str, Any]) -> None:
    """Arq shutdown hook."""
    logger.info("Arq worker shutting down")


# ═════════════════════════════════════════════════════════════════════════════
# Constants: retry & DLQ (Sub-tasks 2.3.4 / 2.3.5)
# ═════════════════════════════════════════════════════════════════════════════

MAX_GENERATION_RETRIES = 3
"""Max attempts for artifact generation before moving to DLQ."""

RETRY_BACKOFF_SECONDS = [2, 4, 8]
"""Exponential backoff (in seconds) between retry attempts."""


# ═════════════════════════════════════════════════════════════════════════════
# Main job function (Sub-task 2.3.3)
# ═════════════════════════════════════════════════════════════════════════════


async def process_generation_job(ctx: dict[str, Any], job_id: str) -> dict[str, Any] | None:
    """Generate a media artifact, upload to storage, and notify the Rust Gateway.

    This is the main Arq job function.  It is called by the Arq worker when
    a job_id appears on the ``gen:jobs:queue`` Redis list.

    Retry behaviour (Sub-task 2.3.4):
    - Generation is attempted up to ``MAX_GENERATION_RETRIES`` (3) times.
    - Between attempts the worker sleeps with exponential backoff (2s, 4s, 8s).
    - Each attempt increments the ``attempts`` counter in the Redis job hash.

    DLQ behaviour (Sub-task 2.3.5):
    - After all retries are exhausted the job is moved to ``gen:jobs:dlq``.
    - An admin can later inspect or re-queue failed jobs from the DLQ.

    Args:
        ctx: Arq context — ``ctx["redis"]`` provides the Redis connection.
        job_id: The async job tracking UUID.

    Returns:
        A dict with ``{"job_id": ..., "status": "completed" | "failed"}`` for
        Arq's result store, or ``None`` if the job could not be found.
    """
    redis = ctx.get("redis")
    if redis is None:
        logger.critical("Arq worker has no Redis connection")
        return {"job_id": job_id, "status": "failed", "error": "no_redis"}

    # Track total job processing time for metrics (Sub-task 3.2.2)
    job_start_time = time.monotonic()

    # Step 1: Update status to 'processing'
    await update_job_status(redis, job_id, "processing")
    logger.info("worker: job %s status -> processing", job_id)

    # Step 2: Load job metadata from Redis
    job_data = await get_job(redis, job_id)
    if job_data is None:
        logger.error("worker: job %s not found in Redis", job_id)
        return None

    generation_id: str = job_data.get("generation_id", "")
    generation_spec_data: dict[str, Any] | None = job_data.get("generation_spec")
    webhook_url: str = job_data.get("webhook_url", "")

    # Sub-task 3.2.1: Log job processing lifecycle event
    log_job_lifecycle(
        "job.processing",
        job_id=job_id,
        generation_id=generation_id,
        status="processing",
    )

    if not generation_spec_data:
        error_msg = f"generation_spec missing for job {job_id}"
        logger.error("worker: %s", error_msg)
        await set_job_error(redis, job_id, "spec_missing", error_msg)
        # Sub-task 3.2.1: Log job failed lifecycle event
        log_job_lifecycle(
            "job.failed",
            job_id=job_id,
            generation_id=generation_id,
            status="failed",
            duration_ms=(time.monotonic() - job_start_time) * 1000,
            error_code="spec_missing",
            error_message=error_msg,
        )
        # Sub-task 3.2.2: Record failure metric
        metrics.job_failure_total.inc()
        await _send_failure_webhook(webhook_url, job_id, generation_id, error_msg)
        return {"job_id": job_id, "status": "failed", "error": "spec_missing"}

    # ── Retry loop (Sub-task 2.3.4) ────────────────────────────────────────
    last_error: str | None = None
    local_artifact_path: str | None = None

    for attempt in range(1, MAX_GENERATION_RETRIES + 1):
        try:
            logger.info(
                "worker: job %s attempt %d/%d",
                job_id, attempt, MAX_GENERATION_RETRIES,
            )

            # Increment the attempt counter in Redis
            key = f"gen:job:{job_id}"
            await redis.hincrby(key, "attempts", 1)

            # Parse the generation spec
            spec = GenerationSpec.model_validate(generation_spec_data)

            # Build render document
            render_document = build_render_document(spec)

            # Generate artifact via generator registry
            if _registry is None:
                raise RuntimeError("Generator registry not initialised")

            generator = _registry.get(spec.export_format)

            gen_request = GenerateRequest(
                generation_id=generation_id,
                generation_spec=spec,
                contracts=RequestContracts(
                    generation_spec="media_generation_spec.v1",
                    artifact_metadata="media_generator_output_metadata.v1",
                ),
            )

            settings = get_settings()
            loop = asyncio.get_running_loop()
            
            import tempfile
            from pathlib import Path
            fd, temp_path_str = tempfile.mkstemp(prefix="klass_media_", suffix=f".{spec.export_format}")
            os.close(fd)
            output_path = Path(temp_path_str)
            local_artifact_path = str(output_path)

            # Sub-task 3.2.3: Wrap artifact generation in a tracing span
            with trace_span(
                "generation.render",
                job_id=job_id,
                generation_id=generation_id,
                attempt=attempt,
                export_format=spec.export_format,
            ):
                artifact_metadata: dict[str, Any] = await loop.run_in_executor(
                    None,
                    lambda: generator.generate(gen_request, render_document, settings, output_path),
                )

            # local_artifact_path is already captured above for cleanup

            # --- PREVIEW GENERATION (Sub-tasks 2.5.1, 2.5.2, 2.5.3) ---
            try:
                logger.info("worker: generating preview for job %s", job_id)
                blueprint = build_slide_blueprint(render_document)
                if _template_registry is None:
                    raise RuntimeError("Template registry not initialised")
                html_master = _template_registry.get_html_master("klass-educational-v1")
                html_engine = HtmlTemplateEngine(master_path=html_master)
                preview_html = html_engine.render(blueprint)
                
                preview_local_path = store_preview_html(
                    preview_html, 
                    generation_id, 
                    title=spec.title or "preview"
                )
                
                preview_url, preview_s3_key = await loop.run_in_executor(
                    None,
                    lambda: upload_artifact(
                        settings,
                        str(preview_local_path),
                        generation_id,
                        "preview.html",
                        prefix="previews"
                    )
                )
                
                artifact_metadata["preview_url"] = preview_url
                artifact_metadata["preview_s3_key"] = preview_s3_key
                
                try:
                    import os
                    os.unlink(preview_local_path)
                except OSError:
                    pass
                logger.info("worker: preview generated and uploaded for job %s", job_id)
            except Exception as e:
                logger.warning("worker: failed to generate/upload preview for job %s: %s", job_id, e)
            # --- END PREVIEW GENERATION ---

            logger.info(
                "worker: job %s artifact generated on attempt %d/%d "
                "(format=%s, size=%d bytes)",
                job_id, attempt, MAX_GENERATION_RETRIES,
                spec.export_format,
                artifact_metadata.get("size_bytes", 0),
            )

            # Step 6: Upload to S3/R2
            # Sub-task 3.2.3: Wrap upload in a tracing span
            with trace_span(
                "generation.upload",
                job_id=job_id,
                generation_id=generation_id,
            ) as upload_span:
                presigned_url, s3_object_key = await _upload_to_storage(generation_id, artifact_metadata)
                upload_span.set_attribute("s3_object_key", s3_object_key)

            # Step 7: Store result in Redis
            await set_job_result(
                redis,
                job_id,
                artifact_metadata=artifact_metadata,
                presigned_url=presigned_url,
                s3_object_key=s3_object_key,
            )

            # Step 8: Send webhook (success)
            # expires_at: NaiveDateTime without timezone (Rust chrono::NaiveDateTime)
            expires_at = (
                datetime.now(timezone.utc) + timedelta(seconds=3600)
            ).strftime("%Y-%m-%dT%H:%M:%S")
            webhook_payload = {
                "job_id": job_id,
                "generation_id": generation_id,
                "status": "completed",
                "s3_object_key": s3_object_key,
                "presigned_url": presigned_url,
                "file_url": presigned_url,
                "expires_at": expires_at,
                "artifact_metadata": artifact_metadata,
            }

            # Sub-task 3.2.3: Wrap webhook call in a tracing span
            with trace_span(
                "generation.webhook",
                job_id=job_id,
                generation_id=generation_id,
                webhook_status="completed",
            ):
                webhook_ok = await send_webhook_with_retry(
                    webhook_url,
                    webhook_payload,
                    settings.shared_secret,
                )

            if not webhook_ok:
                logger.error(
                    "worker: job %s generated but webhook delivery failed "
                    "on attempt %d/%d — artifact is stored (s3_key=%s) "
                    "but Rust Gateway not notified",
                    job_id, attempt, MAX_GENERATION_RETRIES,
                    s3_object_key,
                )

                # ── Webhook exhausted (Sub-task 2.3.7) ────────────────────
                # The artifact was generated successfully but the Rust Gateway
                # was not notified. Mark as WEBHOOK_DELIVERY_FAILED so an admin
                # can investigate and manually re-trigger the webhook.
                await set_job_error(
                    redis, job_id,
                    "WEBHOOK_DELIVERY_FAILED",
                    f"Artifact generated (s3_key={s3_object_key}) but webhook "
                    f"to {webhook_url} exhausted all retries. "
                    "Rust Gateway not notified — manual intervention required.",
                )
                await send_to_dlq(
                    redis, job_id,
                    error_code="WEBHOOK_DELIVERY_FAILED",
                    error_message=f"Webhook to {webhook_url} exhausted after {MAX_WEBHOOK_ATTEMPTS} attempts. "
                                 f"Artifact is stored at s3_key={s3_object_key}.",
                    attempts=MAX_WEBHOOK_ATTEMPTS,
                )

            # Sub-task 3.2.2: Record job success metrics
            job_duration = time.monotonic() - job_start_time
            metrics.job_duration_seconds.observe(job_duration)
            metrics.job_success_total.inc()

            # Sub-task 3.2.1: Log job completed lifecycle event
            log_job_lifecycle(
                "job.completed",
                job_id=job_id,
                generation_id=generation_id,
                status="completed",
                duration_ms=job_duration * 1000,
                extra={
                    "format": spec.export_format,
                    "s3_object_key": s3_object_key,
                    "attempt": attempt,
                    "webhook_delivered": webhook_ok,
                },
            )

            logger.info(
                "worker: job %s completed (generation=%s, format=%s)",
                job_id,
                generation_id,
                spec.export_format,
            )

            return {"job_id": job_id, "status": "completed"}

        except Exception as exc:
            last_error = str(exc)
            logger.warning(
                "worker: job %s attempt %d/%d failed: %s",
                job_id, attempt, MAX_GENERATION_RETRIES,
                last_error,
            )

            # Cleanup temp file from this attempt (if any)
            if local_artifact_path:
                try:
                    os.unlink(local_artifact_path)
                except OSError:
                    pass
                local_artifact_path = None

            # Retry with exponential backoff
            if attempt < MAX_GENERATION_RETRIES:
                delay = RETRY_BACKOFF_SECONDS[attempt - 1]
                logger.info(
                    "worker: retrying job %s in %ds (attempt %d/%d)",
                    job_id, delay, attempt, MAX_GENERATION_RETRIES,
                )
                await asyncio.sleep(delay)

    # ── All retries exhausted → DLQ (Sub-task 2.3.5) ───────────────────────
    error_msg = last_error or "Unknown error after all retries"
    logger.error(
        "worker: job %s exhausted all %d retries — moving to DLQ",
        job_id, MAX_GENERATION_RETRIES,
    )

    await send_to_dlq(
        redis,
        job_id,
        error_code="generation_failed",
        error_message=error_msg,
        attempts=MAX_GENERATION_RETRIES,
    )
    await set_job_error(redis, job_id, "generation_failed", error_msg)

    # Sub-task 3.2.2: Record job failure metrics
    job_duration = time.monotonic() - job_start_time
    metrics.job_duration_seconds.observe(job_duration)
    metrics.job_failure_total.inc()

    # Sub-task 3.2.1: Log job failed lifecycle event
    log_job_lifecycle(
        "job.failed",
        job_id=job_id,
        generation_id=generation_id,
        status="failed",
        duration_ms=job_duration * 1000,
        error_code="generation_failed",
        error_message=error_msg,
        extra={"attempts": MAX_GENERATION_RETRIES},
    )

    await _send_failure_webhook(webhook_url, job_id, generation_id, error_msg)

    return {"job_id": job_id, "status": "failed", "error": error_msg}


# ═════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═════════════════════════════════════════════════════════════════════════════


async def _upload_to_storage(
    generation_id: str,
    artifact_metadata: dict[str, Any],
) -> tuple[str, str]:
    """Upload the generated artifact to S3/R2 and return (presigned_url, s3_key).

    Uses the real S3 client from ``app.storage.upload_artifact()`` (Sub-task 2.4.3).
    The upload runs in a thread pool since ``boto3`` is synchronous.

    Returns:
        A tuple of ``(presigned_url, s3_object_key)``.
    """
    artifact_locator = artifact_metadata.get("artifact_locator", {})
    local_path = artifact_locator.get("value", "")
    filename = artifact_metadata.get("filename", "artifact")

    settings = get_settings()
    loop = asyncio.get_running_loop()

    presigned_url, s3_object_key = await loop.run_in_executor(
        None,
        lambda: upload_artifact(settings, local_path, generation_id, filename),
    )

    logger.info(
        "storage: uploaded artifact for generation %s (key=%s)",
        generation_id,
        s3_object_key,
    )

    return presigned_url, s3_object_key


async def _send_failure_webhook(
    webhook_url: str,
    job_id: str,
    generation_id: str,
    error_message: str,
) -> None:
    """Send a failure webhook to the Rust Gateway (best-effort)."""
    if not webhook_url:
        return

    await send_webhook_with_retry(
        webhook_url,
        {
            "job_id": job_id,
            "generation_id": generation_id,
            "status": "failed",
            "error_code": "generation_failed",
            "error_message": error_message,
        },
        get_settings().shared_secret,
    )


# ═════════════════════════════════════════════════════════════════════════════
# Arq WorkerSettings
# ═════════════════════════════════════════════════════════════════════════════


class WorkerSettings:
    """Arq worker configuration for media generation jobs.

    Usage::

        $ arq app.worker.WorkerSettings

    Or programmatically::

        from arq import run_worker
        await run_worker(WorkerSettings)
    """

    functions = [process_generation_job]
    on_startup = startup
    on_shutdown = shutdown
    keep_result_seconds = 3600
    keep_result_forever = False
    poll_delay = 0.5
    queue_read_limit = 10

    @classmethod
    def from_settings(cls, app_settings: Any) -> type[WorkerSettings]:
        """Create a WorkerSettings subclass configured from app Settings.

        Attributes must live on the *new* class ``__dict__`` because arq's
        ``get_kwargs()`` only inspects ``settings_cls.__dict__`` (not the MRO).
        Inheriting ``functions`` alone is therefore not enough.
        """
        return type(
            "ConfiguredWorkerSettings",
            (cls,),
            {
                "functions": [process_generation_job],
                "on_startup": startup,
                "on_shutdown": shutdown,
                "keep_result_seconds": 3600,
                "keep_result_forever": False,
                "poll_delay": 0.5,
                "queue_read_limit": 10,
                "redis_settings": RedisSettings.from_dsn(
                    app_settings.redis_url,
                    conn_timeout=int(app_settings.redis_socket_connect_timeout_seconds),
                ),
                "max_jobs": app_settings.worker_concurrency,
                "job_timeout": app_settings.worker_job_timeout_seconds,
                "queue_name": "gen:jobs:queue",
            },
        )
