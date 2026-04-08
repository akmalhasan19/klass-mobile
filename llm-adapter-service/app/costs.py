from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Literal

from app.providers.base import ProviderExecutionResult, ProviderUsage

LedgerCacheStatus = Literal["hit", "miss", "bypass"]

LEDGER_COST_PRECISION = Decimal("0.00000001")
PRICE_CATALOG_COST_UNIT = Decimal("1000")

ACTIVE_PRICE_CATALOG_LOOKUP_SQL = """
SELECT
    id,
    provider,
    model,
    currency_code,
    cost_unit,
    input_cost_per_unit_usd,
    output_cost_per_unit_usd,
    request_cost_usd,
    effective_from,
    effective_to,
    is_active,
    created_at,
    updated_at
FROM price_catalog_entries
WHERE provider = %(provider)s
  AND model = %(model)s
  AND is_active = TRUE
  AND effective_from <= %(as_of)s
  AND (effective_to IS NULL OR effective_to > %(as_of)s)
ORDER BY effective_from DESC
LIMIT 1
""".strip()

DAILY_AGGREGATES_SELECT_SQL = """
SELECT *
FROM llm_request_daily_aggregates
WHERE usage_date BETWEEN %(from_date)s AND %(to_date)s
ORDER BY usage_date DESC, route ASC, provider ASC, model ASC
""".strip()

DAILY_ROUTE_AGGREGATES_SELECT_SQL = """
SELECT *
FROM llm_request_daily_route_aggregates
WHERE usage_date BETWEEN %(from_date)s AND %(to_date)s
ORDER BY usage_date DESC, route ASC
""".strip()


@dataclass(frozen=True)
class PriceCatalogEntry:
    provider: str
    model: str
    input_cost_per_unit_usd: Decimal | None = None
    output_cost_per_unit_usd: Decimal | None = None
    request_cost_usd: Decimal | None = None
    currency_code: str = "USD"
    cost_unit: str = "1k_tokens"
    effective_from: datetime | None = None
    effective_to: datetime | None = None

    def __post_init__(self) -> None:
        if self.cost_unit != "1k_tokens":
            raise ValueError("Only 1k_tokens price units are currently supported.")

        if (
            self.input_cost_per_unit_usd is None
            and self.output_cost_per_unit_usd is None
            and self.request_cost_usd is None
        ):
            raise ValueError("A price catalog entry requires at least one price component.")


@dataclass(frozen=True)
class LedgerEntry:
    request_id: str
    generation_id: str
    route: str
    request_type: str
    provider: str
    primary_provider: str
    model: str
    requested_model: str
    latency_ms: float | None
    retry_count: int
    cache_status: LedgerCacheStatus
    final_status: str
    fallback_used: bool
    fallback_reason: str | None
    attempted_providers: tuple[str, ...]
    upstream_request_id: str | None
    provider_response_id: str | None
    provider_model_version: str | None
    finish_reason: str | None
    candidate_index: int | None
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    estimated_cost_usd: Decimal | None
    error_class: str | None = None
    error_code: str | None = None
    cache_key: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def as_record(self) -> dict[str, object]:
        return {
            "request_id": self.request_id,
            "generation_id": self.generation_id,
            "route": self.route,
            "request_type": self.request_type,
            "provider": self.provider,
            "primary_provider": self.primary_provider,
            "model": self.model,
            "requested_model": self.requested_model,
            "latency_ms": self.latency_ms,
            "retry_count": self.retry_count,
            "cache_status": self.cache_status,
            "final_status": self.final_status,
            "error_class": self.error_class,
            "error_code": self.error_code,
            "fallback_used": self.fallback_used,
            "fallback_reason": self.fallback_reason,
            "attempted_providers": list(self.attempted_providers),
            "upstream_request_id": self.upstream_request_id,
            "provider_response_id": self.provider_response_id,
            "provider_model_version": self.provider_model_version,
            "finish_reason": self.finish_reason,
            "candidate_index": self.candidate_index,
            "input_tokens": self.input_tokens,
            "output_tokens": self.output_tokens,
            "total_tokens": self.total_tokens,
            "estimated_cost_usd": self.estimated_cost_usd,
            "cache_key": self.cache_key,
            "metadata": self.metadata,
        }


def estimate_usage_cost(
    usage: ProviderUsage,
    price_catalog_entry: PriceCatalogEntry,
) -> Decimal | None:
    total_cost = Decimal("0")
    has_component = False

    if price_catalog_entry.request_cost_usd is not None:
        total_cost += price_catalog_entry.request_cost_usd
        has_component = True

    input_cost = _estimate_token_cost(
        usage.input_tokens,
        price_catalog_entry.input_cost_per_unit_usd,
    )
    if input_cost is not None:
        total_cost += input_cost
        has_component = True

    output_cost = _estimate_token_cost(
        usage.output_tokens,
        price_catalog_entry.output_cost_per_unit_usd,
    )
    if output_cost is not None:
        total_cost += output_cost
        has_component = True

    if not has_component:
        return None

    return total_cost.quantize(LEDGER_COST_PRECISION, rounding=ROUND_HALF_UP)


def build_ledger_entry_from_execution_result(
    *,
    request_id: str,
    request_type: str,
    result: ProviderExecutionResult,
    retry_count: int = 0,
    cache_status: LedgerCacheStatus = "miss",
    final_status: str = "success",
    price_catalog_entry: PriceCatalogEntry | None = None,
    estimated_cost_usd: Decimal | None = None,
    error_class: str | None = None,
    error_code: str | None = None,
    cache_key: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> LedgerEntry:
    completion = result.completion
    usage = completion.usage

    if estimated_cost_usd is None and price_catalog_entry is not None:
        estimated_cost_usd = estimate_usage_cost(usage, price_catalog_entry)

    return LedgerEntry(
        request_id=request_id.strip(),
        generation_id=completion.generation_id,
        route=completion.route,
        request_type=request_type.strip(),
        provider=completion.provider,
        primary_provider=result.primary_provider,
        model=completion.model,
        requested_model=completion.requested_model,
        latency_ms=usage.latency_ms,
        retry_count=max(0, retry_count),
        cache_status=cache_status,
        final_status=final_status.strip(),
        fallback_used=result.fallback_used,
        fallback_reason=result.fallback_reason,
        attempted_providers=tuple(result.attempted_providers),
        upstream_request_id=usage.upstream_request_id,
        provider_response_id=completion.response_reference.response_id,
        provider_model_version=completion.response_reference.model_version,
        finish_reason=usage.finish_reason,
        candidate_index=completion.response_reference.candidate_index,
        input_tokens=usage.input_tokens,
        output_tokens=usage.output_tokens,
        total_tokens=usage.total_tokens,
        estimated_cost_usd=estimated_cost_usd,
        error_class=_normalize_optional_string(error_class),
        error_code=_normalize_optional_string(error_code),
        cache_key=_normalize_optional_string(cache_key),
        metadata=metadata or {},
    )


def _estimate_token_cost(
    token_count: int | None,
    unit_cost_usd: Decimal | None,
) -> Decimal | None:
    if token_count is None or unit_cost_usd is None:
        return None

    return (Decimal(token_count) / PRICE_CATALOG_COST_UNIT) * unit_cost_usd


def _normalize_optional_string(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip()
    return normalized or None