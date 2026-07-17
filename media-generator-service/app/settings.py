from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from app import SERVICE_VERSION

logger = logging.getLogger("klass-media-generator.settings")


@dataclass(frozen=True)
class Settings:
    service_name: str
    service_version: str
    shared_secret: str
    accepted_shared_secrets: tuple[str, ...]
    request_max_age_seconds: int
    artifact_url_ttl_seconds: int
    public_base_url: str
    log_level: str
    marp_sidecar_node_executable: str
    marp_sidecar_script_path: str
    marp_sidecar_ready_timeout_seconds: int
    marp_sidecar_render_timeout_seconds: int
    marp_sidecar_max_concurrent_renders: int
    marp_sidecar_health_interval_seconds: int
    marp_sidecar_restart_render_count: int
    marp_sidecar_restart_idle_seconds: int

    # ─── Async job queue (Arq / Redis) ───────────────────────────────────
    redis_url: str
    worker_concurrency: int
    worker_job_timeout_seconds: int
    worker_concurrency_auto: bool
    worker_max_concurrency: int
    worker_memory_limit_mb: int

    # ─── Redis connection pool ───────────────────────────────────────────
    redis_max_connections: int
    redis_socket_connect_timeout_seconds: float
    redis_socket_timeout_seconds: float
    redis_health_check_interval_seconds: int

    # ─── Webhook retry tuning ────────────────────────────────────────────
    webhook_max_attempts: int
    webhook_base_backoff_seconds: float
    webhook_max_backoff_seconds: float
    webhook_timeout_seconds: float
    webhook_jitter_enabled: bool

    # ─── S3/R2 Object Storage ─────────────────────────────────────────────
    r2_endpoint: str
    r2_access_key_id: str
    r2_secret_access_key: str
    r2_bucket_name: str
    r2_public_url: str

    @property
    def rotation_enabled(self) -> bool:
        return len(self.accepted_shared_secrets) > 1


def _clean_str(value: str | None, default: str) -> str:
    normalized = (value or "").strip()
    return normalized or default


def _clean_int(value: str | None, default: int, minimum: int = 1) -> int:
    try:
        parsed = int((value or "").strip())
    except ValueError:
        return default

    return max(minimum, parsed)


def _clean_secret_list(primary: str | None, previous: str | None) -> tuple[str, ...]:
    secrets: list[str] = []

    for raw_value in [primary, previous]:
        for candidate in (raw_value or "").split(","):
            normalized = candidate.strip()

            if normalized != "" and normalized not in secrets:
                secrets.append(normalized)

    return tuple(secrets)


def _resolve_worker_concurrency(
    explicit_concurrency: int,
    auto_mode: bool,
    max_concurrency: int,
    memory_limit_mb: int,
) -> int:
    """Determine optimal worker concurrency based on CPU and memory.

    When ``auto_mode`` is True, the concurrency is calculated as::

        min(cpu_count, memory_limit_mb // estimated_mb_per_job, max_concurrency)

    where ``estimated_mb_per_job`` is ~512 MB (conservative estimate for
    PPTX/PDF generation with Chromium sidecar).

    When ``auto_mode`` is False, returns ``explicit_concurrency`` directly.
    """
    ESTIMATED_MB_PER_JOB = 512

    if not auto_mode:
        return explicit_concurrency

    cpu_count = os.cpu_count() or 2
    memory_based_limit = max(1, memory_limit_mb // ESTIMATED_MB_PER_JOB)
    resolved = min(cpu_count, memory_based_limit, max_concurrency)

    logger.info(
        "Worker concurrency auto-resolved: cpu=%d, memory_limit=%dMB, "
        "memory_based_limit=%d, max=%d → concurrency=%d",
        cpu_count,
        memory_limit_mb,
        memory_based_limit,
        max_concurrency,
        resolved,
    )

    return resolved


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    shared_secret = (os.getenv("MEDIA_GENERATION_PYTHON_SHARED_SECRET") or "").strip()

    explicit_concurrency = _clean_int(
        os.getenv("MEDIA_GENERATION_PYTHON_WORKER_CONCURRENCY"),
        4,
        minimum=1,
    )
    auto_mode = os.getenv("MEDIA_GENERATION_PYTHON_WORKER_CONCURRENCY_AUTO", "").lower() in ("1", "true", "yes")
    max_concurrency = _clean_int(
        os.getenv("MEDIA_GENERATION_PYTHON_WORKER_MAX_CONCURRENCY"),
        8,
        minimum=1,
    )
    memory_limit_mb = _clean_int(
        os.getenv("MEDIA_GENERATION_PYTHON_WORKER_MEMORY_LIMIT_MB"),
        4096,
        minimum=512,
    )

    resolved_concurrency = _resolve_worker_concurrency(
        explicit_concurrency, auto_mode, max_concurrency, memory_limit_mb,
    )

    return Settings(
        service_name=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_SERVICE_NAME"),
            "klass-media-generator",
        ),
        service_version=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_SERVICE_VERSION"),
            SERVICE_VERSION,
        ),
        shared_secret=shared_secret,
        accepted_shared_secrets=_clean_secret_list(
            shared_secret,
            os.getenv("MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS"),
        ),
        request_max_age_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS"),
            300,
            minimum=1,
        ),
        artifact_url_ttl_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_ARTIFACT_URL_TTL_SECONDS"),
            900,
            minimum=30,
        ),
        public_base_url=(os.getenv("MEDIA_GENERATION_PYTHON_PUBLIC_BASE_URL") or "").strip().rstrip("/"),
        log_level=_clean_str(os.getenv("MEDIA_GENERATION_PYTHON_LOG_LEVEL"), "info").lower(),
        marp_sidecar_node_executable=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_NODE_EXECUTABLE"),
            "node",
        ),
        marp_sidecar_script_path=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_SCRIPT_PATH"),
            str(Path(__file__).resolve().parent / "engines" / "chromium_sidecar" / "sidecar" / "chromium_sidecar.js"),
        ),
        marp_sidecar_ready_timeout_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_READY_TIMEOUT_SECONDS"),
            30,
            minimum=1,
        ),
        marp_sidecar_render_timeout_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_RENDER_TIMEOUT_SECONDS"),
            30,
            minimum=1,
        ),
        marp_sidecar_max_concurrent_renders=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_MAX_CONCURRENT_RENDERS"),
            4,
            minimum=1,
        ),
        marp_sidecar_health_interval_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_HEALTH_INTERVAL_SECONDS"),
            30,
            minimum=1,
        ),
        marp_sidecar_restart_render_count=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_RESTART_RENDER_COUNT"),
            100,
            minimum=1,
        ),
        marp_sidecar_restart_idle_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_MARP_SIDECAR_RESTART_IDLE_SECONDS"),
            3600,
            minimum=30,
        ),
        redis_url=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_REDIS_URL"),
            "redis://localhost:6379/1",
        ),
        worker_concurrency=resolved_concurrency,
        worker_job_timeout_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_WORKER_JOB_TIMEOUT_SECONDS"),
            300,
            minimum=30,
        ),
        worker_concurrency_auto=auto_mode,
        worker_max_concurrency=max_concurrency,
        worker_memory_limit_mb=memory_limit_mb,
        # ─── Redis connection pool ───────────────────────────────────────
        redis_max_connections=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_REDIS_MAX_CONNECTIONS"),
            20,
            minimum=1,
        ),
        redis_socket_connect_timeout_seconds=float(_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_REDIS_SOCKET_CONNECT_TIMEOUT"),
            5,
            minimum=1,
        )),
        redis_socket_timeout_seconds=float(_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_REDIS_SOCKET_TIMEOUT"),
            5,
            minimum=1,
        )),
        redis_health_check_interval_seconds=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_REDIS_HEALTH_CHECK_INTERVAL"),
            30,
            minimum=5,
        ),
        # ─── Webhook retry tuning ────────────────────────────────────────
        webhook_max_attempts=_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_WEBHOOK_MAX_ATTEMPTS"),
            5,
            minimum=1,
        ),
        webhook_base_backoff_seconds=float(_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_WEBHOOK_BASE_BACKOFF_SECONDS"),
            2,
            minimum=1,
        )),
        webhook_max_backoff_seconds=float(_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_WEBHOOK_MAX_BACKOFF_SECONDS"),
            32,
            minimum=1,
        )),
        webhook_timeout_seconds=float(_clean_int(
            os.getenv("MEDIA_GENERATION_PYTHON_WEBHOOK_TIMEOUT_SECONDS"),
            10,
            minimum=1,
        )),
        webhook_jitter_enabled=os.getenv(
            "MEDIA_GENERATION_PYTHON_WEBHOOK_JITTER_ENABLED", "true"
        ).lower() in ("1", "true", "yes"),
        r2_endpoint=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_R2_ENDPOINT"),
            "https://<account_id>.r2.cloudflarestorage.com",
        ),
        r2_access_key_id=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_R2_ACCESS_KEY_ID"),
            "",
        ),
        r2_secret_access_key=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_R2_SECRET_ACCESS_KEY"),
            "",
        ),
        r2_bucket_name=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_R2_BUCKET_NAME"),
            "klass-media",
        ),
        r2_public_url=_clean_str(
            os.getenv("MEDIA_GENERATION_PYTHON_R2_PUBLIC_URL"),
            "",
        ),
    )


def clear_settings_cache() -> None:
    get_settings.cache_clear()
