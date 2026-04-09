from __future__ import annotations

import json
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Literal

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.contracts import (
    INTERPRET_ROUTE,
    OPS_SUMMARY_SCHEMA_VERSION,
    RESPOND_ROUTE,
)
from app.database import get_database_pool
from app.errors import CostTrackingError
from app.providers.base import ProviderExecutionResult, ProviderRoute, ProviderUsage
from app.settings import Settings, get_settings

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

PRICE_CATALOG_UPSERT_SQL = """
INSERT INTO price_catalog_entries (
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
    updated_at
) VALUES (
    %(provider)s,
    %(model)s,
    %(currency_code)s,
    %(cost_unit)s,
    %(input_cost_per_unit_usd)s,
    %(output_cost_per_unit_usd)s,
    %(request_cost_usd)s,
    %(effective_from)s,
    %(effective_to)s,
    TRUE,
    NOW()
)
ON CONFLICT (provider, model, effective_from)
DO UPDATE SET
    currency_code = EXCLUDED.currency_code,
    cost_unit = EXCLUDED.cost_unit,
    input_cost_per_unit_usd = EXCLUDED.input_cost_per_unit_usd,
    output_cost_per_unit_usd = EXCLUDED.output_cost_per_unit_usd,
    request_cost_usd = EXCLUDED.request_cost_usd,
    effective_to = EXCLUDED.effective_to,
    is_active = TRUE,
    updated_at = NOW()
RETURNING
    provider,
    model,
    currency_code,
    cost_unit,
    input_cost_per_unit_usd,
    output_cost_per_unit_usd,
    request_cost_usd,
    effective_from,
    effective_to
""".strip()

LEDGER_UPSERT_SQL = """
INSERT INTO llm_request_ledger (
    request_id,
    generation_id,
    route,
    request_type,
    provider,
    primary_provider,
    model,
    requested_model,
    latency_ms,
    retry_count,
    cache_status,
    final_status,
    error_class,
    error_code,
    fallback_used,
    fallback_reason,
    attempted_providers,
    upstream_request_id,
    provider_response_id,
    provider_model_version,
    finish_reason,
    candidate_index,
    input_tokens,
    output_tokens,
    total_tokens,
    estimated_cost_usd,
    cache_key,
    metadata,
    created_at,
    completed_at
) VALUES (
    %(request_id)s,
    %(generation_id)s,
    %(route)s,
    %(request_type)s,
    %(provider)s,
    %(primary_provider)s,
    %(model)s,
    %(requested_model)s,
    %(latency_ms)s,
    %(retry_count)s,
    %(cache_status)s,
    %(final_status)s,
    %(error_class)s,
    %(error_code)s,
    %(fallback_used)s,
    %(fallback_reason)s,
    %(attempted_providers)s::jsonb,
    %(upstream_request_id)s,
    %(provider_response_id)s,
    %(provider_model_version)s,
    %(finish_reason)s,
    %(candidate_index)s,
    %(input_tokens)s,
    %(output_tokens)s,
    %(total_tokens)s,
    %(estimated_cost_usd)s,
    %(cache_key)s,
    %(metadata)s::jsonb,
    %(created_at)s,
    %(completed_at)s
)
ON CONFLICT (request_id)
DO UPDATE SET
    generation_id = EXCLUDED.generation_id,
    route = EXCLUDED.route,
    request_type = EXCLUDED.request_type,
    provider = EXCLUDED.provider,
    primary_provider = EXCLUDED.primary_provider,
    model = EXCLUDED.model,
    requested_model = EXCLUDED.requested_model,
    latency_ms = EXCLUDED.latency_ms,
    retry_count = EXCLUDED.retry_count,
    cache_status = EXCLUDED.cache_status,
    final_status = EXCLUDED.final_status,
    error_class = EXCLUDED.error_class,
    error_code = EXCLUDED.error_code,
    fallback_used = EXCLUDED.fallback_used,
    fallback_reason = EXCLUDED.fallback_reason,
    attempted_providers = EXCLUDED.attempted_providers,
    upstream_request_id = EXCLUDED.upstream_request_id,
    provider_response_id = EXCLUDED.provider_response_id,
    provider_model_version = EXCLUDED.provider_model_version,
    finish_reason = EXCLUDED.finish_reason,
    candidate_index = EXCLUDED.candidate_index,
    input_tokens = EXCLUDED.input_tokens,
    output_tokens = EXCLUDED.output_tokens,
    total_tokens = EXCLUDED.total_tokens,
    estimated_cost_usd = EXCLUDED.estimated_cost_usd,
    cache_key = EXCLUDED.cache_key,
    metadata = EXCLUDED.metadata,
    completed_at = EXCLUDED.completed_at
RETURNING *
""".strip()

ROUTE_LATENCY_SUMMARY_SELECT_SQL = """
SELECT
    route,
    ROUND(AVG(latency_ms), 2) AS average_latency_ms
FROM llm_request_ledger
WHERE DATE_TRUNC('day', created_at)::date BETWEEN %(from_date)s AND %(to_date)s
  AND latency_ms IS NOT NULL
GROUP BY route
ORDER BY route ASC
""".strip()

PROVIDER_MODEL_LATENCY_SUMMARY_SELECT_SQL = """
SELECT
    route,
    provider,
    model,
    ROUND(AVG(latency_ms), 2) AS average_latency_ms
FROM llm_request_ledger
WHERE DATE_TRUNC('day', created_at)::date BETWEEN %(from_date)s AND %(to_date)s
  AND latency_ms IS NOT NULL
GROUP BY route, provider, model
ORDER BY route ASC, provider ASC, model ASC
""".strip()

ROUTE_DENY_SUMMARY_SELECT_SQL = """
SELECT
    policy.route,
    COALESCE(SUM(bucket.deny_count), 0) AS deny_count,
    COALESCE(SUM(bucket.request_count), 0) AS allowed_request_count,
    ROUND(
        CASE
            WHEN COALESCE(SUM(bucket.request_count), 0) + COALESCE(SUM(bucket.deny_count), 0) = 0 THEN 0::numeric
            ELSE COALESCE(SUM(bucket.deny_count), 0)::numeric
                / (COALESCE(SUM(bucket.request_count), 0) + COALESCE(SUM(bucket.deny_count), 0))::numeric
        END,
        6
    ) AS deny_rate,
    MAX(bucket.last_seen_at) AS last_denied_at
FROM rate_limit_buckets AS bucket
JOIN rate_limit_policies AS policy ON policy.id = bucket.policy_id
WHERE policy.scope_type = 'route'
  AND bucket.window_unit = 'day'
  AND policy.route IN ('interpret', 'respond')
  AND bucket.window_started_at::date BETWEEN %(from_date)s AND %(to_date)s
GROUP BY policy.route
ORDER BY policy.route ASC
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


@dataclass(frozen=True)
class ResolvedUsageCost:
    estimated_cost_usd: Decimal | None
    source: Literal["price_catalog", "route_default", "explicit", "cache_hit", "unknown"]
    price_catalog_entry: PriceCatalogEntry | None = None
    actual_provider_cost_usd: Decimal | None = None


@dataclass(frozen=True)
class DailyAggregateRecord:
    usage_date: date
    route: str
    provider: str
    model: str
    request_count: int
    cache_hit_count: int
    cache_miss_count: int
    cache_bypass_count: int
    cache_hit_ratio: Decimal
    retry_volume: int
    fallback_count: int
    error_count: int
    input_tokens: int
    output_tokens: int
    total_tokens: int
    estimated_cost_usd: Decimal
    last_request_at: datetime | None

    @classmethod
    def from_row(cls, row: dict[str, object]) -> "DailyAggregateRecord":
        return cls(
            usage_date=_normalize_date(row["usage_date"]),
            route=str(row["route"]),
            provider=str(row["provider"]),
            model=str(row["model"]),
            request_count=int(row["request_count"]),
            cache_hit_count=int(row["cache_hit_count"]),
            cache_miss_count=int(row["cache_miss_count"]),
            cache_bypass_count=int(row["cache_bypass_count"]),
            cache_hit_ratio=_normalize_decimal(row["cache_hit_ratio"]),
            retry_volume=int(row["retry_volume"]),
            fallback_count=int(row["fallback_count"]),
            error_count=int(row["error_count"]),
            input_tokens=int(row["input_tokens"]),
            output_tokens=int(row["output_tokens"]),
            total_tokens=int(row["total_tokens"]),
            estimated_cost_usd=_normalize_decimal(row["estimated_cost_usd"]),
            last_request_at=_normalize_optional_datetime(row.get("last_request_at")),
        )


@dataclass(frozen=True)
class DailyRouteAggregateRecord:
    usage_date: date
    route: str
    request_count: int
    cache_hit_count: int
    cache_miss_count: int
    cache_bypass_count: int
    cache_hit_ratio: Decimal
    retry_volume: int
    fallback_count: int
    error_count: int
    input_tokens: int
    output_tokens: int
    total_tokens: int
    estimated_cost_usd: Decimal
    last_request_at: datetime | None

    @classmethod
    def from_row(cls, row: dict[str, object]) -> "DailyRouteAggregateRecord":
        return cls(
            usage_date=_normalize_date(row["usage_date"]),
            route=str(row["route"]),
            request_count=int(row["request_count"]),
            cache_hit_count=int(row["cache_hit_count"]),
            cache_miss_count=int(row["cache_miss_count"]),
            cache_bypass_count=int(row["cache_bypass_count"]),
            cache_hit_ratio=_normalize_decimal(row["cache_hit_ratio"]),
            retry_volume=int(row["retry_volume"]),
            fallback_count=int(row["fallback_count"]),
            error_count=int(row["error_count"]),
            input_tokens=int(row["input_tokens"]),
            output_tokens=int(row["output_tokens"]),
            total_tokens=int(row["total_tokens"]),
            estimated_cost_usd=_normalize_decimal(row["estimated_cost_usd"]),
            last_request_at=_normalize_optional_datetime(row.get("last_request_at")),
        )


@dataclass(frozen=True)
class RouteDenySummary:
    route: ProviderRoute
    deny_count: int
    allowed_request_count: int
    deny_rate: Decimal
    last_denied_at: datetime | None


@dataclass(frozen=True)
class LedgerFailureContext:
    request_id: str
    generation_id: str
    route: ProviderRoute
    request_type: str
    provider: str
    primary_provider: str
    model: str
    requested_model: str
    retry_count: int = 0
    cache_status: LedgerCacheStatus = "miss"
    final_status: str = "failed"
    fallback_used: bool = False
    fallback_reason: str | None = None
    attempted_providers: tuple[str, ...] = ()
    error_class: str | None = None
    error_code: str | None = None
    cache_key: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
    usage: ProviderUsage | None = None
    provider_response_id: str | None = None
    provider_model_version: str | None = None
    candidate_index: int | None = None


class AdapterCostService:
    def __init__(
        self,
        settings: Settings | None = None,
        pool: ConnectionPool | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.pool = pool

    def upsert_price_catalog_entry(
        self,
        entry: PriceCatalogEntry,
        *,
        connection: psycopg.Connection | None = None,
    ) -> PriceCatalogEntry:
        effective_from = _normalize_datetime(entry.effective_from or datetime.now(timezone.utc))

        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute(
                    PRICE_CATALOG_UPSERT_SQL,
                    {
                        "provider": entry.provider.strip().lower(),
                        "model": entry.model.strip(),
                        "currency_code": entry.currency_code.strip().upper(),
                        "cost_unit": entry.cost_unit,
                        "input_cost_per_unit_usd": entry.input_cost_per_unit_usd,
                        "output_cost_per_unit_usd": entry.output_cost_per_unit_usd,
                        "request_cost_usd": entry.request_cost_usd,
                        "effective_from": effective_from,
                        "effective_to": _normalize_optional_datetime(entry.effective_to),
                    },
                )
                row = cursor.fetchone()

        if row is None:
            raise RuntimeError("Price catalog upsert did not return a row.")

        return _build_price_catalog_entry(row)

    def lookup_active_price_catalog_entry(
        self,
        *,
        provider: str,
        model: str,
        as_of: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> PriceCatalogEntry | None:
        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute(
                    ACTIVE_PRICE_CATALOG_LOOKUP_SQL,
                    {
                        "provider": provider.strip().lower(),
                        "model": model.strip(),
                        "as_of": _normalize_datetime(as_of or datetime.now(timezone.utc)),
                    },
                )
                row = cursor.fetchone()

        return _build_price_catalog_entry(row) if row is not None else None

    def resolve_estimated_cost(
        self,
        *,
        route: ProviderRoute,
        provider: str,
        model: str,
        usage: ProviderUsage | None = None,
        explicit_estimated_cost_usd: Decimal | None = None,
        actual_provider_cost_usd: Decimal | None = None,
        fallback_to_route_default: bool = True,
        as_of: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> ResolvedUsageCost:
        if explicit_estimated_cost_usd is not None:
            return ResolvedUsageCost(
                estimated_cost_usd=_normalize_decimal(explicit_estimated_cost_usd),
                source="explicit",
                actual_provider_cost_usd=_normalize_optional_decimal(actual_provider_cost_usd),
            )

        price_catalog_entry = self.lookup_active_price_catalog_entry(
            provider=provider,
            model=model,
            as_of=as_of,
            connection=connection,
        )

        if price_catalog_entry is not None and usage is not None:
            estimated_cost_usd = estimate_usage_cost(usage, price_catalog_entry)
            if estimated_cost_usd is not None:
                return ResolvedUsageCost(
                    estimated_cost_usd=estimated_cost_usd,
                    source="price_catalog",
                    price_catalog_entry=price_catalog_entry,
                    actual_provider_cost_usd=_normalize_optional_decimal(actual_provider_cost_usd),
                )

        if fallback_to_route_default:
            return ResolvedUsageCost(
                estimated_cost_usd=self.default_estimated_cost_for_route(route),
                source="route_default",
                price_catalog_entry=price_catalog_entry,
                actual_provider_cost_usd=_normalize_optional_decimal(actual_provider_cost_usd),
            )

        return ResolvedUsageCost(
            estimated_cost_usd=None,
            source="unknown",
            price_catalog_entry=price_catalog_entry,
            actual_provider_cost_usd=_normalize_optional_decimal(actual_provider_cost_usd),
        )

    def record_execution_result(
        self,
        *,
        request_id: str,
        request_type: str,
        result: ProviderExecutionResult,
        retry_count: int = 0,
        cache_status: LedgerCacheStatus = "miss",
        final_status: str = "success",
        estimated_cost_usd: Decimal | None = None,
        actual_provider_cost_usd: Decimal | None = None,
        error_class: str | None = None,
        error_code: str | None = None,
        cache_key: str | None = None,
        metadata: dict[str, Any] | None = None,
        occurred_at: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> LedgerEntry:
        completion = result.completion
        current_time = _normalize_datetime(occurred_at or datetime.now(timezone.utc))

        with self._connection_scope(connection) as active_connection:
            resolved_cost = self.resolve_estimated_cost(
                route=completion.route,
                provider=completion.provider,
                model=completion.model,
                usage=completion.usage,
                explicit_estimated_cost_usd=estimated_cost_usd,
                actual_provider_cost_usd=actual_provider_cost_usd,
                fallback_to_route_default=True,
                as_of=current_time,
                connection=active_connection,
            )
            ledger_entry = build_ledger_entry_from_execution_result(
                request_id=request_id,
                request_type=request_type,
                result=result,
                retry_count=retry_count,
                cache_status=cache_status,
                final_status=final_status,
                price_catalog_entry=resolved_cost.price_catalog_entry,
                estimated_cost_usd=resolved_cost.estimated_cost_usd,
                error_class=error_class,
                error_code=error_code,
                cache_key=cache_key,
                metadata=_merge_cost_metadata(metadata, resolved_cost),
            )
            return self.write_ledger_entry(
                ledger_entry,
                occurred_at=current_time,
                connection=active_connection,
            )

    def record_cache_hit(
        self,
        *,
        request_id: str,
        generation_id: str,
        route: ProviderRoute,
        request_type: str,
        provider: str,
        model: str,
        requested_model: str,
        cache_key: str,
        metadata: dict[str, Any] | None = None,
        occurred_at: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> LedgerEntry:
        ledger_entry = build_cache_hit_ledger_entry(
            request_id=request_id,
            generation_id=generation_id,
            route=route,
            request_type=request_type,
            provider=provider,
            model=model,
            requested_model=requested_model,
            cache_key=cache_key,
            metadata=_merge_cost_metadata(
                metadata,
                ResolvedUsageCost(
                    estimated_cost_usd=Decimal("0"),
                    source="cache_hit",
                ),
            ),
        )
        return self.write_ledger_entry(
            ledger_entry,
            occurred_at=occurred_at,
            connection=connection,
        )

    def record_failure(
        self,
        context: LedgerFailureContext,
        *,
        estimated_cost_usd: Decimal | None = None,
        actual_provider_cost_usd: Decimal | None = None,
        fallback_to_route_default: bool = False,
        occurred_at: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> LedgerEntry:
        current_time = _normalize_datetime(occurred_at or datetime.now(timezone.utc))

        with self._connection_scope(connection) as active_connection:
            resolved_cost = self.resolve_estimated_cost(
                route=context.route,
                provider=context.provider,
                model=context.model,
                usage=context.usage,
                explicit_estimated_cost_usd=estimated_cost_usd,
                actual_provider_cost_usd=actual_provider_cost_usd,
                fallback_to_route_default=fallback_to_route_default,
                as_of=current_time,
                connection=active_connection,
            )
            ledger_entry = build_failure_ledger_entry(
                context,
                estimated_cost_usd=resolved_cost.estimated_cost_usd,
                metadata=_merge_cost_metadata(context.metadata, resolved_cost),
            )
            return self.write_ledger_entry(
                ledger_entry,
                occurred_at=current_time,
                connection=active_connection,
            )

    def write_ledger_entry(
        self,
        ledger_entry: LedgerEntry,
        *,
        occurred_at: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> LedgerEntry:
        current_time = _normalize_datetime(occurred_at or datetime.now(timezone.utc))
        params = _build_ledger_upsert_params(ledger_entry, occurred_at=current_time)

        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute(LEDGER_UPSERT_SQL, params)
                row = cursor.fetchone()

        if row is None:
            raise RuntimeError("Ledger upsert did not return a row.")

        return _build_ledger_entry(row)

    def daily_aggregates(
        self,
        *,
        from_date: date,
        to_date: date,
        connection: psycopg.Connection | None = None,
    ) -> tuple[DailyAggregateRecord, ...]:
        rows = self._fetch_all(
            DAILY_AGGREGATES_SELECT_SQL,
            {"from_date": from_date, "to_date": to_date},
            connection=connection,
        )
        return tuple(DailyAggregateRecord.from_row(row) for row in rows)

    def daily_route_aggregates(
        self,
        *,
        from_date: date,
        to_date: date,
        connection: psycopg.Connection | None = None,
    ) -> tuple[DailyRouteAggregateRecord, ...]:
        rows = self._fetch_all(
            DAILY_ROUTE_AGGREGATES_SELECT_SQL,
            {"from_date": from_date, "to_date": to_date},
            connection=connection,
        )
        return tuple(DailyRouteAggregateRecord.from_row(row) for row in rows)

    def route_latency_summaries(
        self,
        *,
        from_date: date,
        to_date: date,
        connection: psycopg.Connection | None = None,
    ) -> dict[str, float]:
        rows = self._fetch_all(
            ROUTE_LATENCY_SUMMARY_SELECT_SQL,
            {"from_date": from_date, "to_date": to_date},
            connection=connection,
        )
        return {
            str(row["route"]): float(row["average_latency_ms"])
            for row in rows
            if row.get("average_latency_ms") is not None
        }

    def provider_model_latency_summaries(
        self,
        *,
        from_date: date,
        to_date: date,
        connection: psycopg.Connection | None = None,
    ) -> dict[tuple[str, str, str], float]:
        rows = self._fetch_all(
            PROVIDER_MODEL_LATENCY_SUMMARY_SELECT_SQL,
            {"from_date": from_date, "to_date": to_date},
            connection=connection,
        )
        return {
            (str(row["route"]), str(row["provider"]), str(row["model"])): float(row["average_latency_ms"])
            for row in rows
            if row.get("average_latency_ms") is not None
        }

    def route_deny_summaries(
        self,
        *,
        from_date: date,
        to_date: date,
        connection: psycopg.Connection | None = None,
    ) -> dict[str, RouteDenySummary]:
        rows = self._fetch_all(
            ROUTE_DENY_SUMMARY_SELECT_SQL,
            {"from_date": from_date, "to_date": to_date},
            connection=connection,
        )
        return {
            str(row["route"]): RouteDenySummary(
                route=str(row["route"]),
                deny_count=int(row["deny_count"]),
                allowed_request_count=int(row["allowed_request_count"]),
                deny_rate=_normalize_decimal(row["deny_rate"]),
                last_denied_at=_normalize_optional_datetime(row.get("last_denied_at")),
            )
            for row in rows
        }

    def build_operator_summary(
        self,
        *,
        days: int = 1,
        as_of: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> dict[str, object]:
        current_time = _normalize_datetime(as_of or datetime.now(timezone.utc))
        normalized_days = max(1, days)
        to_date = current_time.date()
        from_date = to_date - timedelta(days=normalized_days - 1)

        with self._connection_scope(connection) as active_connection:
            daily_route_rows = self.daily_route_aggregates(
                from_date=from_date,
                to_date=to_date,
                connection=active_connection,
            )
            daily_provider_rows = self.daily_aggregates(
                from_date=from_date,
                to_date=to_date,
                connection=active_connection,
            )
            route_latencies = self.route_latency_summaries(
                from_date=from_date,
                to_date=to_date,
                connection=active_connection,
            )
            provider_latencies = self.provider_model_latency_summaries(
                from_date=from_date,
                to_date=to_date,
                connection=active_connection,
            )
            route_denies = self.route_deny_summaries(
                from_date=from_date,
                to_date=to_date,
                connection=active_connection,
            )

        route_metrics = _build_route_metrics_payload(
            settings=self.settings,
            route_rows=daily_route_rows,
            route_latencies=route_latencies,
            route_denies=route_denies,
        )
        provider_metrics = _build_provider_model_metrics_payload(
            provider_rows=daily_provider_rows,
            provider_latencies=provider_latencies,
        )

        return {
            "schema_version": OPS_SUMMARY_SCHEMA_VERSION,
            "service_name": self.settings.service_name,
            "service_version": self.settings.service_version,
            "generated_at": current_time.isoformat(),
            "window": {
                "from_date": from_date.isoformat(),
                "to_date": to_date.isoformat(),
                "days": normalized_days,
            },
            "active_routes": _build_active_route_payload(self.settings),
            "routes": route_metrics,
            "provider_models": provider_metrics,
        }

    def default_estimated_cost_for_route(self, route: ProviderRoute) -> Decimal:
        if route == INTERPRET_ROUTE:
            return self.settings.interpretation_default_estimated_cost_usd

        if route == RESPOND_ROUTE:
            return self.settings.delivery_default_estimated_cost_usd

        raise CostTrackingError(
            code="route_unsupported",
            message="The requested route is not supported for cost tracking.",
            status_code=500,
            details={"route": route},
            retryable=False,
        )

    def _fetch_all(
        self,
        query: str,
        params: dict[str, object],
        *,
        connection: psycopg.Connection | None = None,
    ) -> list[dict[str, object]]:
        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute(query, params)
                return list(cursor.fetchall())

    @contextmanager
    def _connection_scope(self, connection: psycopg.Connection | None):
        if connection is not None:
            yield connection
            return

        if self.settings.database_url == "":
            raise CostTrackingError(
                code="database_url_missing",
                message="LLM_ADAPTER_DATABASE_URL is not configured.",
                status_code=503,
                details={"config": "LLM_ADAPTER_DATABASE_URL"},
                retryable=False,
            )

        pool = self.pool or get_database_pool(self.settings)
        with pool.connection() as pooled_connection:
            yield pooled_connection


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


def build_cache_hit_ledger_entry(
    *,
    request_id: str,
    generation_id: str,
    route: ProviderRoute,
    request_type: str,
    provider: str,
    model: str,
    requested_model: str,
    cache_key: str,
    metadata: dict[str, Any] | None = None,
) -> LedgerEntry:
    normalized_provider = provider.strip().lower()
    normalized_model = model.strip()

    return LedgerEntry(
        request_id=request_id.strip(),
        generation_id=generation_id.strip(),
        route=route,
        request_type=request_type.strip(),
        provider=normalized_provider,
        primary_provider=normalized_provider,
        model=normalized_model,
        requested_model=requested_model.strip(),
        latency_ms=None,
        retry_count=0,
        cache_status="hit",
        final_status="success",
        fallback_used=False,
        fallback_reason=None,
        attempted_providers=(normalized_provider,),
        upstream_request_id=None,
        provider_response_id=None,
        provider_model_version=None,
        finish_reason=None,
        candidate_index=None,
        input_tokens=None,
        output_tokens=None,
        total_tokens=None,
        estimated_cost_usd=Decimal("0"),
        cache_key=cache_key.strip(),
        metadata=metadata or {},
    )


def build_failure_ledger_entry(
    context: LedgerFailureContext,
    *,
    estimated_cost_usd: Decimal | None = None,
    metadata: dict[str, Any] | None = None,
) -> LedgerEntry:
    usage = context.usage
    attempted_providers = context.attempted_providers or tuple(
        dict.fromkeys([context.primary_provider.strip().lower(), context.provider.strip().lower()])
    )

    return LedgerEntry(
        request_id=context.request_id.strip(),
        generation_id=context.generation_id.strip(),
        route=context.route,
        request_type=context.request_type.strip(),
        provider=context.provider.strip().lower(),
        primary_provider=context.primary_provider.strip().lower(),
        model=context.model.strip(),
        requested_model=context.requested_model.strip(),
        latency_ms=usage.latency_ms if usage is not None else None,
        retry_count=max(0, context.retry_count),
        cache_status=context.cache_status,
        final_status=context.final_status.strip(),
        fallback_used=context.fallback_used,
        fallback_reason=_normalize_optional_string(context.fallback_reason),
        attempted_providers=tuple(provider.strip().lower() for provider in attempted_providers if provider.strip() != ""),
        upstream_request_id=usage.upstream_request_id if usage is not None else None,
        provider_response_id=_normalize_optional_string(context.provider_response_id),
        provider_model_version=_normalize_optional_string(context.provider_model_version),
        finish_reason=usage.finish_reason if usage is not None else None,
        candidate_index=context.candidate_index,
        input_tokens=usage.input_tokens if usage is not None else None,
        output_tokens=usage.output_tokens if usage is not None else None,
        total_tokens=usage.total_tokens if usage is not None else None,
        estimated_cost_usd=estimated_cost_usd,
        error_class=_normalize_optional_string(context.error_class),
        error_code=_normalize_optional_string(context.error_code),
        cache_key=_normalize_optional_string(context.cache_key),
        metadata=metadata or {},
    )


def build_operator_summary_payload(
    settings: Settings,
    *,
    days: int = 1,
) -> dict[str, object]:
    service = AdapterCostService(settings=settings)
    return service.build_operator_summary(days=days)


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


def _normalize_decimal(value: Decimal | object) -> Decimal:
    if isinstance(value, Decimal):
        return value

    return Decimal(str(value))


def _normalize_optional_decimal(value: object | None) -> Decimal | None:
    if value is None:
        return None

    return _normalize_decimal(value)


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value.astimezone(timezone.utc)


def _normalize_optional_datetime(value: object | None) -> datetime | None:
    if value is None:
        return None

    if isinstance(value, datetime):
        return _normalize_datetime(value)

    raise TypeError("Expected datetime value.")


def _normalize_date(value: object) -> date:
    if isinstance(value, date) and not isinstance(value, datetime):
        return value

    if isinstance(value, datetime):
        return _normalize_datetime(value).date()

    raise TypeError("Expected date value.")


def _build_price_catalog_entry(row: dict[str, object]) -> PriceCatalogEntry:
    return PriceCatalogEntry(
        provider=str(row["provider"]),
        model=str(row["model"]),
        input_cost_per_unit_usd=_normalize_optional_decimal(row.get("input_cost_per_unit_usd")),
        output_cost_per_unit_usd=_normalize_optional_decimal(row.get("output_cost_per_unit_usd")),
        request_cost_usd=_normalize_optional_decimal(row.get("request_cost_usd")),
        currency_code=str(row["currency_code"]),
        cost_unit=str(row["cost_unit"]),
        effective_from=_normalize_optional_datetime(row.get("effective_from")),
        effective_to=_normalize_optional_datetime(row.get("effective_to")),
    )


def _merge_cost_metadata(
    metadata: dict[str, Any] | None,
    resolved_cost: ResolvedUsageCost,
) -> dict[str, Any]:
    merged = dict(metadata or {})
    merged["cost_source"] = resolved_cost.source

    if resolved_cost.estimated_cost_usd is not None:
        merged["estimated_cost_usd"] = _format_decimal(resolved_cost.estimated_cost_usd)

    if resolved_cost.actual_provider_cost_usd is not None:
        merged["actual_provider_cost_usd"] = _format_decimal(resolved_cost.actual_provider_cost_usd)

    if resolved_cost.price_catalog_entry is not None:
        merged["price_catalog_provider"] = resolved_cost.price_catalog_entry.provider
        merged["price_catalog_model"] = resolved_cost.price_catalog_entry.model
        if resolved_cost.price_catalog_entry.effective_from is not None:
            merged["price_catalog_effective_from"] = resolved_cost.price_catalog_entry.effective_from.isoformat()

    return merged


def _build_ledger_upsert_params(
    ledger_entry: LedgerEntry,
    *,
    occurred_at: datetime,
) -> dict[str, object]:
    return {
        **ledger_entry.as_record(),
        "attempted_providers": json.dumps(list(ledger_entry.attempted_providers)),
        "metadata": json.dumps(ledger_entry.metadata, sort_keys=True),
        "created_at": occurred_at,
        "completed_at": occurred_at,
    }


def _build_ledger_entry(row: dict[str, object]) -> LedgerEntry:
    attempted_providers = row.get("attempted_providers")
    metadata = row.get("metadata")

    return LedgerEntry(
        request_id=str(row["request_id"]),
        generation_id=str(row["generation_id"]),
        route=str(row["route"]),
        request_type=str(row["request_type"]),
        provider=str(row["provider"]),
        primary_provider=str(row["primary_provider"]),
        model=str(row["model"]),
        requested_model=str(row["requested_model"]),
        latency_ms=float(row["latency_ms"]) if row.get("latency_ms") is not None else None,
        retry_count=int(row["retry_count"]),
        cache_status=str(row["cache_status"]),
        final_status=str(row["final_status"]),
        fallback_used=bool(row["fallback_used"]),
        fallback_reason=_normalize_optional_string(row.get("fallback_reason") if isinstance(row.get("fallback_reason"), str) else None),
        attempted_providers=tuple(_normalize_json_array(attempted_providers)),
        upstream_request_id=_normalize_optional_string(row.get("upstream_request_id") if isinstance(row.get("upstream_request_id"), str) else None),
        provider_response_id=_normalize_optional_string(row.get("provider_response_id") if isinstance(row.get("provider_response_id"), str) else None),
        provider_model_version=_normalize_optional_string(row.get("provider_model_version") if isinstance(row.get("provider_model_version"), str) else None),
        finish_reason=_normalize_optional_string(row.get("finish_reason") if isinstance(row.get("finish_reason"), str) else None),
        candidate_index=int(row["candidate_index"]) if row.get("candidate_index") is not None else None,
        input_tokens=int(row["input_tokens"]) if row.get("input_tokens") is not None else None,
        output_tokens=int(row["output_tokens"]) if row.get("output_tokens") is not None else None,
        total_tokens=int(row["total_tokens"]) if row.get("total_tokens") is not None else None,
        estimated_cost_usd=_normalize_optional_decimal(row.get("estimated_cost_usd")),
        error_class=_normalize_optional_string(row.get("error_class") if isinstance(row.get("error_class"), str) else None),
        error_code=_normalize_optional_string(row.get("error_code") if isinstance(row.get("error_code"), str) else None),
        cache_key=_normalize_optional_string(row.get("cache_key") if isinstance(row.get("cache_key"), str) else None),
        metadata=_normalize_json_object(metadata),
    )


def _normalize_json_array(value: object) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value]

    if isinstance(value, str):
        decoded = json.loads(value)
        if isinstance(decoded, list):
            return [str(item) for item in decoded]

    return []


def _normalize_json_object(value: object) -> dict[str, Any]:
    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        decoded = json.loads(value)
        if isinstance(decoded, dict):
            return decoded

    return {}


def _build_active_route_payload(settings: Settings) -> list[dict[str, object]]:
    return [
        {
            "route": INTERPRET_ROUTE,
            "provider": settings.active_interpretation_provider,
            "default_model": _default_model_for_route(settings, INTERPRET_ROUTE),
            "fallback_provider": settings.interpretation_fallback_provider,
        },
        {
            "route": RESPOND_ROUTE,
            "provider": settings.active_delivery_provider,
            "default_model": _default_model_for_route(settings, RESPOND_ROUTE),
            "fallback_provider": settings.delivery_fallback_provider,
        },
    ]


def _build_route_metrics_payload(
    *,
    settings: Settings,
    route_rows: tuple[DailyRouteAggregateRecord, ...],
    route_latencies: dict[str, float],
    route_denies: dict[str, RouteDenySummary],
) -> list[dict[str, object]]:
    grouped_rows: dict[str, list[DailyRouteAggregateRecord]] = {}
    for row in route_rows:
        grouped_rows.setdefault(row.route, []).append(row)

    payload: list[dict[str, object]] = []
    for route in [INTERPRET_ROUTE, RESPOND_ROUTE]:
        rows = grouped_rows.get(route, [])
        request_count = sum(row.request_count for row in rows)
        cache_hit_count = sum(row.cache_hit_count for row in rows)
        retry_volume = sum(row.retry_volume for row in rows)
        fallback_count = sum(row.fallback_count for row in rows)
        error_count = sum(row.error_count for row in rows)
        input_tokens = sum(row.input_tokens for row in rows)
        output_tokens = sum(row.output_tokens for row in rows)
        total_tokens = sum(row.total_tokens for row in rows)
        estimated_cost_usd = sum((row.estimated_cost_usd for row in rows), Decimal("0"))
        last_request_at = max((row.last_request_at for row in rows if row.last_request_at is not None), default=None)
        deny_summary = route_denies.get(
            route,
            RouteDenySummary(route=route, deny_count=0, allowed_request_count=request_count, deny_rate=Decimal("0"), last_denied_at=None),
        )
        cache_hit_ratio = (
            round(cache_hit_count / request_count, 6)
            if request_count > 0
            else 0.0
        )
        deny_rate_denominator = request_count + deny_summary.deny_count

        payload.append(
            {
                "route": route,
                "request_count": request_count,
                "cache_hit_ratio": cache_hit_ratio,
                "deny_count": deny_summary.deny_count,
                "deny_rate": round(deny_summary.deny_count / deny_rate_denominator, 6)
                if deny_rate_denominator > 0
                else 0.0,
                "average_latency_ms": route_latencies.get(route),
                "retry_volume": retry_volume,
                "fallback_count": fallback_count,
                "error_count": error_count,
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "total_tokens": total_tokens,
                "total_estimated_cost_usd": _format_decimal(estimated_cost_usd),
                "last_request_at": last_request_at.isoformat() if last_request_at is not None else None,
            }
        )

    return payload


def _build_provider_model_metrics_payload(
    *,
    provider_rows: tuple[DailyAggregateRecord, ...],
    provider_latencies: dict[tuple[str, str, str], float],
) -> list[dict[str, object]]:
    grouped_rows: dict[tuple[str, str, str], list[DailyAggregateRecord]] = {}
    for row in provider_rows:
        grouped_rows.setdefault((row.route, row.provider, row.model), []).append(row)

    payload: list[dict[str, object]] = []
    for key in sorted(grouped_rows.keys()):
        route, provider, model = key
        rows = grouped_rows[key]
        request_count = sum(row.request_count for row in rows)
        cache_hit_count = sum(row.cache_hit_count for row in rows)
        fallback_count = sum(row.fallback_count for row in rows)
        error_count = sum(row.error_count for row in rows)
        estimated_cost_usd = sum((row.estimated_cost_usd for row in rows), Decimal("0"))
        last_request_at = max((row.last_request_at for row in rows if row.last_request_at is not None), default=None)

        payload.append(
            {
                "route": route,
                "provider": provider,
                "model": model,
                "request_count": request_count,
                "cache_hit_ratio": round(cache_hit_count / request_count, 6) if request_count > 0 else 0.0,
                "average_latency_ms": provider_latencies.get(key),
                "fallback_count": fallback_count,
                "error_count": error_count,
                "total_estimated_cost_usd": _format_decimal(estimated_cost_usd),
                "last_request_at": last_request_at.isoformat() if last_request_at is not None else None,
            }
        )

    return payload


def _default_model_for_route(settings: Settings, route: ProviderRoute) -> str:
    if route == INTERPRET_ROUTE:
        if settings.active_interpretation_provider == "openai":
            return settings.openai_interpretation_model

        return settings.gemini_interpretation_model

    if settings.active_delivery_provider == "openai":
        return settings.openai_delivery_model

    return settings.gemini_delivery_model


def _format_decimal(value: Decimal) -> str:
    return f"{value.quantize(LEDGER_COST_PRECISION, rounding=ROUND_HALF_UP)}"