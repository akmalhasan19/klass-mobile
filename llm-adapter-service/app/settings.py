from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache

from app import SERVICE_VERSION
from app.contracts import DEFAULT_DELIVERY_PROVIDER, DEFAULT_INTERPRETATION_PROVIDER


@dataclass(frozen=True)
class Settings:
    service_name: str
    service_version: str
    log_level: str
    database_url: str
    database_connect_timeout_seconds: int
    shared_secret: str
    accepted_shared_secrets: tuple[str, ...]
    request_max_age_seconds: int
    active_interpretation_provider: str
    active_delivery_provider: str
    gemini_api_key: str
    openai_api_key: str

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
        gemini_api_key=_clean_str(os.getenv("LLM_ADAPTER_GEMINI_API_KEY")),
        openai_api_key=_clean_str(os.getenv("LLM_ADAPTER_OPENAI_API_KEY")),
    )


def clear_settings_cache() -> None:
    get_settings.cache_clear()
