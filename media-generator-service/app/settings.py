from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from app import SERVICE_VERSION


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


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    shared_secret = (os.getenv("MEDIA_GENERATION_PYTHON_SHARED_SECRET") or "").strip()

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
    )


def clear_settings_cache() -> None:
    get_settings.cache_clear()
