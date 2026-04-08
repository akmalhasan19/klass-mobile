from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache

from app import SERVICE_VERSION
from app.contracts import (
    DEFAULT_PROVIDER_FALLBACK_ERROR_CODES,
    DEFAULT_DELIVERY_PROVIDER,
    DEFAULT_INTERPRETATION_PROVIDER,
    GEMINI_API_VERSION,
    GEMINI_BASE_URL,
    GEMINI_DEFAULT_DELIVERY_MODEL,
    GEMINI_DEFAULT_INTERPRETATION_MODEL,
    OPENAI_BASE_URL,
    OPENAI_DEFAULT_DELIVERY_MODEL,
    OPENAI_DEFAULT_INTERPRETATION_MODEL,
)


@dataclass(frozen=True)
class Settings:
    service_name: str
    service_version: str
    log_level: str
    database_url: str
    database_connect_timeout_seconds: int
    database_pool_min_size: int
    database_pool_max_size: int
    database_pool_max_idle_seconds: int
    database_auto_migrate: bool
    upstream_timeout_seconds: int
    shared_secret: str
    accepted_shared_secrets: tuple[str, ...]
    request_max_age_seconds: int
    active_interpretation_provider: str
    active_delivery_provider: str
    allow_route_provider_divergence: bool
    interpretation_fallback_provider: str | None
    delivery_fallback_provider: str | None
    provider_fallback_error_codes: tuple[str, ...]
    gemini_api_key: str
    gemini_base_url: str
    gemini_api_version: str
    gemini_interpretation_model: str
    gemini_delivery_model: str
    openai_api_key: str
    openai_base_url: str
    openai_interpretation_model: str
    openai_delivery_model: str
    openai_organization: str
    openai_project: str

    @property
    def rotation_enabled(self) -> bool:
        return len(self.accepted_shared_secrets) > 1


def _clean_str(value: str | None, default: str = "") -> str:
    normalized = (value or "").strip()
    return normalized or default


def _clean_int(value: str | None, default: int, minimum: int = 1) -> int:
    try:
        parsed = int((value or "").strip())
    except ValueError:
        return default

    return max(minimum, parsed)


def _clean_provider(value: str | None, default: str) -> str:
    return _clean_str(value, default).lower()


def _clean_optional_provider(value: str | None) -> str | None:
    normalized = _clean_str(value).lower()
    return normalized or None


def _clean_bool(value: str | None, default: bool) -> bool:
    normalized = (value or "").strip().lower()

    if normalized == "":
        return default

    if normalized in {"1", "true", "yes", "on"}:
        return True

    if normalized in {"0", "false", "no", "off"}:
        return False

    return default


def _clean_csv(value: str | None, default: tuple[str, ...] = ()) -> tuple[str, ...]:
    items: list[str] = []

    for raw_item in (value or "").split(","):
        normalized = raw_item.strip()

        if normalized != "" and normalized not in items:
            items.append(normalized)

    return tuple(items) or default


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
    shared_secret = _clean_str(os.getenv("LLM_ADAPTER_SHARED_SECRET"))

    return Settings(
        service_name=_clean_str(os.getenv("LLM_ADAPTER_SERVICE_NAME"), "klass-llm-adapter"),
        service_version=_clean_str(os.getenv("LLM_ADAPTER_SERVICE_VERSION"), SERVICE_VERSION),
        log_level=_clean_str(os.getenv("LLM_ADAPTER_LOG_LEVEL"), "info").lower(),
        database_url=_clean_str(os.getenv("LLM_ADAPTER_DATABASE_URL")),
        database_connect_timeout_seconds=_clean_int(
            os.getenv("LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS"),
            3,
            minimum=1,
        ),
        database_pool_min_size=_clean_int(
            os.getenv("LLM_ADAPTER_DATABASE_POOL_MIN_SIZE"),
            1,
            minimum=1,
        ),
        database_pool_max_size=_clean_int(
            os.getenv("LLM_ADAPTER_DATABASE_POOL_MAX_SIZE"),
            5,
            minimum=1,
        ),
        database_pool_max_idle_seconds=_clean_int(
            os.getenv("LLM_ADAPTER_DATABASE_POOL_MAX_IDLE_SECONDS"),
            300,
            minimum=1,
        ),
        database_auto_migrate=_clean_bool(
            os.getenv("LLM_ADAPTER_DATABASE_AUTO_MIGRATE"),
            False,
        ),
        upstream_timeout_seconds=_clean_int(
            os.getenv("LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS"),
            30,
            minimum=1,
        ),
        shared_secret=shared_secret,
        accepted_shared_secrets=_clean_secret_list(
            shared_secret,
            os.getenv("LLM_ADAPTER_SHARED_SECRET_PREVIOUS"),
        ),
        request_max_age_seconds=_clean_int(
            os.getenv("LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS"),
            300,
            minimum=1,
        ),
        active_interpretation_provider=_clean_provider(
            os.getenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER"),
            DEFAULT_INTERPRETATION_PROVIDER,
        ),
        active_delivery_provider=_clean_provider(
            os.getenv("LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER"),
            DEFAULT_DELIVERY_PROVIDER,
        ),
        allow_route_provider_divergence=_clean_bool(
            os.getenv("LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE"),
            True,
        ),
        interpretation_fallback_provider=_clean_optional_provider(
            os.getenv("LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER"),
        ),
        delivery_fallback_provider=_clean_optional_provider(
            os.getenv("LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER"),
        ),
        provider_fallback_error_codes=_clean_csv(
            os.getenv("LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES"),
            DEFAULT_PROVIDER_FALLBACK_ERROR_CODES,
        ),
        gemini_api_key=_clean_str(os.getenv("LLM_ADAPTER_GEMINI_API_KEY")),
        gemini_base_url=_clean_str(os.getenv("LLM_ADAPTER_GEMINI_BASE_URL"), GEMINI_BASE_URL),
        gemini_api_version=_clean_str(os.getenv("LLM_ADAPTER_GEMINI_API_VERSION"), GEMINI_API_VERSION),
        gemini_interpretation_model=_clean_str(
            os.getenv("LLM_ADAPTER_GEMINI_INTERPRET_MODEL"),
            GEMINI_DEFAULT_INTERPRETATION_MODEL,
        ),
        gemini_delivery_model=_clean_str(
            os.getenv("LLM_ADAPTER_GEMINI_DELIVERY_MODEL"),
            GEMINI_DEFAULT_DELIVERY_MODEL,
        ),
        openai_api_key=_clean_str(os.getenv("LLM_ADAPTER_OPENAI_API_KEY")),
        openai_base_url=_clean_str(os.getenv("LLM_ADAPTER_OPENAI_BASE_URL"), OPENAI_BASE_URL),
        openai_interpretation_model=_clean_str(
            os.getenv("LLM_ADAPTER_OPENAI_INTERPRET_MODEL"),
            OPENAI_DEFAULT_INTERPRETATION_MODEL,
        ),
        openai_delivery_model=_clean_str(
            os.getenv("LLM_ADAPTER_OPENAI_DELIVERY_MODEL"),
            OPENAI_DEFAULT_DELIVERY_MODEL,
        ),
        openai_organization=_clean_str(os.getenv("LLM_ADAPTER_OPENAI_ORGANIZATION")),
        openai_project=_clean_str(os.getenv("LLM_ADAPTER_OPENAI_PROJECT")),
    )


def clear_settings_cache() -> None:
    get_settings.cache_clear()
