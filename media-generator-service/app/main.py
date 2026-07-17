from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from uuid import uuid4

import redis.asyncio as aioredis
from fastapi import Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from arq.connections import ArqRedis

from app.auth import verify_request_signature
from app.contracts import (
    ARTIFACT_METADATA_VERSION,
    GENERATION_SPEC_VERSION,
    HEALTH_SCHEMA_VERSION,
    IMPLEMENTED_EXPORT_FORMATS,
    RESPONSE_SCHEMA_VERSION,
    SIGNATURE_ALGORITHM,
)
from app.engines.chromium_sidecar.sidecar.sidecar_manager import SidecarManager, build_sidecar_manager
from app.errors import ContractValidationError, MediaGeneratorError, ServiceMisconfiguredError
from app.generators.registry import GeneratorRegistry
from app.job_store import create_job, get_job
from app.models import (
    GenerateErrorResponse,
    GenerateJobRequest,
    GenerateRequest,
    JobStatusResponse,
)
from app.settings import Settings, get_settings
from app.templates.registry import TemplateRegistry
from app.observability import metrics, refresh_redis_gauges
from app.webhook_sender import close_shared_client

logger = logging.getLogger("klass-media-generator")
registry = GeneratorRegistry()

# Module-level sidecar manager — started during lifespan, accessible by
# health endpoint and by generators (via the registry or module import).
sidecar_manager: SidecarManager | None = None

# Module-level template registry — loaded during lifespan, provides
# master templates for all formats (PPTX .pptx+manifest, DOCX .docx,
# HTML .html for PDF + preview).  Single source of truth for every
# template_id across the three engine pillars.
template_registry: TemplateRegistry | None = None

# Module-level Redis client for async job queue (Task 2.1.2).
# Initialized during lifespan; used by ``POST /v1/jobs``.
redis_client: ArqRedis | None = None


def build_error_response(request: Request, exc: MediaGeneratorError) -> JSONResponse:
    response_payload = GenerateErrorResponse.model_validate(
        {
            "schema_version": RESPONSE_SCHEMA_VERSION,
            "request_id": getattr(request.state, "request_id", str(uuid4())),
            "status": "failed",
            "error": {
                "code": exc.code,
                "message": exc.message,
                "retryable": exc.retryable,
                "laravel_error_code_hint": exc.laravel_error_code_hint,
                "details": exc.details,
            },
        }
    )

    return JSONResponse(status_code=exc.status_code, content=response_payload.model_dump(mode="python"))


def configure_logging(settings: Settings) -> None:
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


@asynccontextmanager
async def lifespan(_: FastAPI):
    configure_logging(get_settings())
    settings = get_settings()
    global sidecar_manager, template_registry, registry, redis_client

    # ── Bootstrap Redis client for async job queue ────────────────────
    logger.info("Connecting to Redis for async job queue…")
    try:
        pool = aioredis.ConnectionPool.from_url(
            settings.redis_url,
            max_connections=settings.redis_max_connections,
            socket_connect_timeout=settings.redis_socket_connect_timeout_seconds,
            socket_timeout=settings.redis_socket_timeout_seconds,
            health_check_interval=settings.redis_health_check_interval_seconds,
            decode_responses=False,
        )
        redis_client = ArqRedis(
            connection_pool=pool,
            default_queue_name="gen:jobs:queue",
        )
        # Verify connection
        async with redis_client.pipeline() as pipe:
            await pipe.ping().execute()
        logger.info(
            "Redis connected (url=%s, max_connections=%d, socket_timeout=%ds, health_check=%ds)",
            settings.redis_url,
            settings.redis_max_connections,
            settings.redis_socket_timeout_seconds,
            settings.redis_health_check_interval_seconds,
        )
    except Exception as exc:
        logger.critical("Failed to connect to Redis: %s", exc)
        redis_client = None
        raise ServiceMisconfiguredError(
            "Redis connection failed. Async job processing will be unavailable.",
            {"startup_error": str(exc)},
        ) from exc

    # ── Bootstrap template registry (PPTX, DOCX, HTML masters) ────────
    logger.info("Loading master templates (PPTX, DOCX, HTML)…")
    try:
        from pathlib import Path

        templates_dir = Path(__file__).resolve().parent / "templates"
        tpl_registry = TemplateRegistry()
        tpl_registry.load_templates(templates_dir)
        template_registry = tpl_registry
        logger.info(
            "Template registry loaded: %s",
            template_registry.template_ids,
        )
    except Exception as exc:
        logger.critical("Failed to load master templates: %s", exc)
        template_registry = None
        raise ServiceMisconfiguredError(
            "Master templates failed to load. "
            "PPTX, DOCX, PDF, and HTML previews will be unavailable.",
            {"startup_error": str(exc)},
        ) from exc

    # ── Bootstrap sidecar ──────────────────────────────────────────────
    logger.info("Starting Chromium sidecar (Node + Playwright warm)…")
    try:
        manager = build_sidecar_manager(settings)
        await manager.start()
        sidecar_manager = manager
        logger.info("Chromium sidecar started and ready")
    except Exception as exc:
        logger.critical("Failed to start Chromium sidecar: %s", exc)
        sidecar_manager = None
        raise ServiceMisconfiguredError(
            "Chromium sidecar (Node + Playwright) failed to start. "
            "HTML previews and PDF generation will be unavailable.",
            {"startup_error": str(exc)},
        ) from exc

    # ── Rebuild generator registry with injected dependencies ──────────
    # The module-level ``registry`` is created at import time (before deps
    # exist). Now that the template registry and sidecar are live, rebuild
    # it so generators receive their real dependencies instead of relying
    # on lazy fallback / circular imports per-request.
    logger.info(
        "Rebuilding generator registry with template_registry=%s, "
        "sidecar_manager=%s",
        template_registry is not None,
        sidecar_manager is not None,
    )
    registry = GeneratorRegistry(
        template_registry=template_registry,
        sidecar_manager=sidecar_manager,
        event_loop=asyncio.get_running_loop(),
    )

    try:
        yield
    finally:
        # ── Shutdown shared webhook client ──────────────────────────────
        logger.info("Closing shared webhook HTTP client…")
        try:
            await close_shared_client()
        except Exception as exc:
            logger.warning("Error during webhook client shutdown: %s", exc)

        # ── Shutdown Redis client ──────────────────────────────────────
        if redis_client is not None:
            logger.info("Closing Redis connection…")
            try:
                await redis_client.close()
            except Exception as exc:
                logger.warning("Error during Redis shutdown: %s", exc)
            redis_client = None
            logger.info("Redis connection closed")

        # ── Shutdown sidecar ───────────────────────────────────────────
        if sidecar_manager is not None:
            logger.info("Shutting down Chromium sidecar…")
            try:
                await sidecar_manager.stop()
            except Exception as exc:
                logger.warning("Error during Chromium sidecar shutdown: %s", exc)
            sidecar_manager = None
            logger.info("Chromium sidecar stopped")


app = FastAPI(
    title="Klass Media Generator",
    version=get_settings().service_version,
    lifespan=lifespan,
)


def get_redis() -> ArqRedis:
    if redis_client is None:
        raise ServiceMisconfiguredError(
            "Redis is not configured. Async job operations are unavailable.",
            {"config": "MEDIA_GENERATION_PYTHON_REDIS_URL"},
        )
    return redis_client


@app.middleware("http")
async def attach_request_id(request: Request, call_next):
    request_id = str(uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-Id"] = request_id
    return response


@app.exception_handler(MediaGeneratorError)
async def media_generator_error_handler(request: Request, exc: MediaGeneratorError) -> JSONResponse:
    return build_error_response(request, exc)


@app.exception_handler(RequestValidationError)
async def request_validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    validation_error = ContractValidationError(
        "request_contract_invalid",
        "Incoming request payload failed validation.",
        {"errors": exc.errors()},
    )
    return await media_generator_error_handler(request, validation_error)


@app.exception_handler(Exception)
async def unexpected_error_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled media generator exception", exc_info=exc)
    return build_error_response(
        request,
        MediaGeneratorError(
            status_code=500,
            code="internal_error",
            message="An unexpected error occurred while generating the artifact.",
            details={},
            retryable=True,
            laravel_error_code_hint="python_service_unavailable",
        ),
    )


def health_payload(settings: Settings) -> dict[str, object]:
    # Sidecar status — simple sync properties, no RPC call needed.
    sidecar_info: dict[str, object] = {"enabled": False}
    if sidecar_manager is not None:
        sidecar_info = {
            "enabled": True,
            "running": sidecar_manager.is_running,
            "ready": sidecar_manager.is_ready,
            "uptime_seconds": round(sidecar_manager.uptime_seconds, 1),
        }

    # Template registry status
    template_info: dict[str, object] = {"enabled": False}
    if template_registry is not None:
        template_info = {
            "enabled": True,
            "templates": template_registry.template_ids,
        }

    return {
        "schema_version": HEALTH_SCHEMA_VERSION,
        "status": "ok",
        "service": settings.service_name,
        "version": settings.service_version,
        "supported_formats": list(IMPLEMENTED_EXPORT_FORMATS),
        "contracts": {
            "generation_spec": GENERATION_SPEC_VERSION,
            "artifact_metadata": ARTIFACT_METADATA_VERSION,
            "response": RESPONSE_SCHEMA_VERSION,
        },
        "auth": {
            "signature_algorithm": SIGNATURE_ALGORITHM,
            "configured": settings.shared_secret != "",
            "rotation_enabled": settings.rotation_enabled,
            "accepted_secret_count": len(settings.accepted_shared_secrets),
            "max_request_age_seconds": settings.request_max_age_seconds,
        },
        "sidecar": sidecar_info,
        "templates": template_info,
    }


@app.get("/health")
def health(settings: Settings = Depends(get_settings)) -> dict[str, object]:
    return health_payload(settings)


@app.get("/v1/health")
def versioned_health(settings: Settings = Depends(get_settings)) -> dict[str, object]:
    return health_payload(settings)


# ═════════════════════════════════════════════════════════════════════════════
# Async job submission endpoint (Phase 2, Task 2.1.2)
# ═════════════════════════════════════════════════════════════════════════════


@app.post("/v1/jobs", status_code=202)
async def submit_job(
    payload: GenerateJobRequest,
    request: Request,
    settings: Settings = Depends(get_settings),
    redis: aioredis.Redis = Depends(get_redis),
    _: None = Depends(verify_request_signature),
) -> dict[str, object]:
    """Enqueue a media generation job for async processing.

    Called by the Rust Gateway (fire-and-forget). The job metadata is stored
    in Redis and the Arq worker will process it asynchronously, uploading the
    generated artifact to S3 and sending a webhook back to the Gateway.
    """
    header_generation_id = getattr(request.state, "authenticated_generation_id", None)
    if header_generation_id != payload.generation_id:
        raise ContractValidationError(
            "generation_id_mismatch",
            "Header generation id does not match request body generation id.",
            {
                "header_generation_id": header_generation_id,
                "body_generation_id": payload.generation_id,
            },
        )

    # Serialise the generation_spec to a plain dict for Redis storage
    spec_dict = payload.generation_spec.model_dump(mode="python")

    await create_job(
        redis,
        job_id=payload.job_id,
        generation_id=payload.generation_id,
        generation_spec=spec_dict,
        webhook_url=payload.webhook_url,
    )

    # Enqueue to Arq worker
    await redis.enqueue_job("process_generation_job", payload.job_id, _job_id=payload.job_id)

    response = JobStatusResponse(
        job_id=payload.job_id,
        generation_id=payload.generation_id,
        status="pending",
    )

    logger.info(
        "POST /v1/jobs: enqueued job %s for generation %s",
        payload.job_id,
        payload.generation_id,
    )

    return response.model_dump(mode="python")


# ═════════════════════════════════════════════════════════════════════════════
# Async job status endpoint (Phase 2, Task 2.1.3)
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/v1/jobs/{job_id}")
async def get_job_status(
    job_id: str,
    settings: Settings = Depends(get_settings),
    redis: aioredis.Redis = Depends(get_redis),
    _: None = Depends(verify_request_signature),
) -> dict[str, object]:
    """Retrieve the current status of an async generation job.

    Returns the full job metadata from Redis, including status, artifact
    metadata (if completed), or error details (if failed).

    This endpoint is primarily for debugging and administrative purposes.
    The Rust Gateway receives job completion via webhook, not by polling
    this endpoint.
    """
    job_data = await get_job(redis, job_id)
    if job_data is None:
        raise ContractValidationError(
            "job_not_found",
            f"Job '{job_id}' not found.",
            {"job_id": job_id},
        )

    # Validate status against known values — fall back to "failed" for
    # unknown/legacy statuses.
    _VALID_JOB_STATUSES = {"pending", "processing", "completed", "failed"}
    status = job_data.get("status", "unknown")
    if status not in _VALID_JOB_STATUSES:
        status = "failed"

    response = JobStatusResponse(
        job_id=job_id,
        generation_id=job_data.get("generation_id", ""),
        status=status,  # type: ignore[arg-type]
        # Completed fields
        artifact_metadata=job_data.get("artifact_metadata"),
        presigned_url=job_data.get("presigned_url"),
        s3_object_key=job_data.get("s3_object_key"),
        # Failed fields
        error_code=job_data.get("error_code"),
        error_message=job_data.get("error_message"),
    )

    logger.info(
        "GET /v1/jobs/%s: status=%s for generation %s",
        job_id,
        status,
        job_data.get("generation_id"),
    )

    return response.model_dump(mode="python")


# ═════════════════════════════════════════════════════════════════════════════
# Deprecated sync endpoint (Phase 2, Task 2.1.5)
# ═════════════════════════════════════════════════════════════════════════════


@app.post("/v1/generate")
async def generate_artifact_deprecated(
    payload: GenerateRequest,
    request: Request,
    settings: Settings = Depends(get_settings),
    _: None = Depends(verify_request_signature),
) -> JSONResponse:
    """Deprecated: Use the async workflow via `POST /v1/jobs` instead.

    This endpoint has been superseded by the async job submission workflow.
    Clients should migrate to `POST /v1/jobs` which returns immediately
    and processes generation in the background.

    Migration guide:
      POST /v1/jobs
      {
        "generation_id": "<uuid>",
        "job_id": "<uuid>",
        "generation_spec": { ... },
        "webhook_url": "http://gateway:8080/internal/media-generations/webhook"
      }

    The Rust Gateway will:
    1. Create the generation row (status=pending)
    2. Enqueue via POST /v1/jobs
    3. Get 202 Accepted immediately
    4. Receive webhook callback when completed
    """
    logger.warning(
        "DEPRECATED: POST /v1/generate called for generation %s — "
        "migrate to POST /v1/jobs",
        payload.generation_id,
    )

    return JSONResponse(
        status_code=410,
        content={
            "schema_version": RESPONSE_SCHEMA_VERSION,
            "request_id": request.state.request_id,
            "status": "failed",
            "error": {
                "code": "endpoint_deprecated",
                "message": (
                    "POST /v1/generate is deprecated and has been replaced by "
                    "POST /v1/jobs (async workflow). "
                    "Please migrate to the async job submission endpoint. "
                    "See migration guide in the endpoint documentation."
                ),
                "retryable": False,
                "laravel_error_code_hint": "endpoint_deprecated",
                "details": {
                    "migration_endpoint": "POST /v1/jobs",
                    "migration_guide": (
                        "Send a GenerateJobRequest with generation_id, job_id, "
                        "generation_spec, and webhook_url to POST /v1/jobs. "
                        "The Rust Gateway will handle the rest."
                    ),
                },
            },
        },
    )


# ═════════════════════════════════════════════════════════════════════════════
# Metrics endpoint (Phase 3, Sub-task 3.2.2)
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/v1/metrics")
async def get_metrics(
    redis: aioredis.Redis = Depends(get_redis),
) -> dict[str, object]:
    """Expose in-process observability metrics.

    Returns a JSON snapshot of all tracked metrics including:
    - Job duration histogram (count, sum, min, max, avg, p50, p95, p99)
    - Job success/failure counters
    - Queue depth gauge (refreshed from Redis)
    - Webhook delivery attempts (success/failure counters)
    - Webhook delivery latency histogram
    - DLQ depth gauge (refreshed from Redis)

    This endpoint is intended for monitoring dashboards and alerting systems.
    """
    # Refresh Redis-based gauges before returning snapshot
    await refresh_redis_gauges(redis)

    return metrics.snapshot()
