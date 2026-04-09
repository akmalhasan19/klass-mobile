from __future__ import annotations

from app.contracts import (
    LLM_FALLBACK_REASON_HEADER,
    LLM_FALLBACK_USED_HEADER,
    LLM_MODEL_HEADER,
    LLM_PRIMARY_PROVIDER_HEADER,
    LLM_PROVIDER_HEADER,
)


def build_llm_response_headers(
    *,
    provider: str,
    model: str,
    primary_provider: str | None = None,
    fallback_used: bool | None = None,
    fallback_reason: str | None = None,
) -> dict[str, str]:
    headers: dict[str, str] = {}

    normalized_provider = provider.strip().lower()
    normalized_model = model.strip()
    normalized_primary_provider = (primary_provider or normalized_provider).strip().lower()
    normalized_fallback_reason = (fallback_reason or "").strip()

    if normalized_provider != "":
        headers[LLM_PROVIDER_HEADER] = normalized_provider

    if normalized_model != "":
        headers[LLM_MODEL_HEADER] = normalized_model

    if normalized_primary_provider != "":
        headers[LLM_PRIMARY_PROVIDER_HEADER] = normalized_primary_provider

    if fallback_used is not None:
        headers[LLM_FALLBACK_USED_HEADER] = "true" if fallback_used else "false"

    if normalized_fallback_reason != "":
        headers[LLM_FALLBACK_REASON_HEADER] = normalized_fallback_reason

    return headers