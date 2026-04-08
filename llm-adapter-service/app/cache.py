from __future__ import annotations

import hashlib
import json
from typing import Any

from app.contracts import INTERPRET_ROUTE, RESPOND_ROUTE
from app.models import DeliveryRequest, InterpretationRequest

CACHE_KEY_SCHEMA_VERSION = "llm_adapter_cache.v1"


def build_interpretation_cache_document(
    payload: InterpretationRequest,
    *,
    provider: str,
    model: str,
) -> dict[str, Any]:
    return _build_cache_document(
        route=INTERPRET_ROUTE,
        request_type=payload.request_type,
        provider=provider,
        model=model,
        instruction=payload.instruction,
        input_payload=payload.input.model_dump(mode="python"),
    )


def build_delivery_cache_document(
    payload: DeliveryRequest,
    *,
    provider: str,
    model: str,
) -> dict[str, Any]:
    return _build_cache_document(
        route=RESPOND_ROUTE,
        request_type=payload.request_type,
        provider=provider,
        model=model,
        instruction=payload.instruction,
        input_payload=payload.input.model_dump(mode="python"),
    )


def build_interpretation_cache_key(
    payload: InterpretationRequest,
    *,
    provider: str,
    model: str,
) -> str:
    return _hash_cache_document(
        build_interpretation_cache_document(payload, provider=provider, model=model)
    )


def build_delivery_cache_key(
    payload: DeliveryRequest,
    *,
    provider: str,
    model: str,
) -> str:
    return _hash_cache_document(
        build_delivery_cache_document(payload, provider=provider, model=model)
    )


def _build_cache_document(
    *,
    route: str,
    request_type: str,
    provider: str,
    model: str,
    instruction: str,
    input_payload: dict[str, Any],
) -> dict[str, Any]:
    return _normalize_value(
        {
            "schema_version": CACHE_KEY_SCHEMA_VERSION,
            "route": route.strip(),
            "request_type": request_type.strip(),
            "provider": provider.strip().lower(),
            "model": model.strip(),
            "instruction": instruction.strip(),
            "input": input_payload,
        }
    )


def _hash_cache_document(document: dict[str, Any]) -> str:
    payload = json.dumps(
        document,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )

    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _normalize_value(value: Any) -> Any:
    if isinstance(value, dict):
        normalized_dict: dict[str, Any] = {}

        for key, raw_item in value.items():
            normalized_item = _normalize_value(raw_item)

            if normalized_item is None:
                continue

            normalized_dict[key] = normalized_item

        return normalized_dict

    if isinstance(value, list):
        return [_normalize_value(item) for item in value]

    if isinstance(value, str):
        return value.strip()

    return value