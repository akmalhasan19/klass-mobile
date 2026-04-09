from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Literal

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.contracts import INTERPRET_ROUTE, RESPOND_ROUTE
from app.errors import GovernancePolicyError
from app.providers.base import ProviderRoute, ProviderUsage
from app.rate_limits import (
    RATE_LIMIT_BUCKET_UPSERT_SQL,
    RATE_LIMIT_DIMENSION_ALL,
    RATE_LIMIT_FIXED_WINDOW,
    RATE_LIMIT_ROUTE_ALL,
    RateLimitBucketMutation,
    RateLimitPolicyRecord,
    RateLimitScopeType,
    RateLimitWindowUnit,
    build_rate_limit_bucket_params,
    get_fixed_window_end,
    get_fixed_window_start,
)
from app.settings import Settings, get_settings

GovernanceAction = Literal["allow", "deny", "degrade"]
GovernanceBudgetStatus = Literal["healthy", "warning", "exhausted", "disabled", "unavailable"]

RATE_LIMIT_POLICY_UPSERT_SQL = """
INSERT INTO rate_limit_policies (
    scope_type,
    strategy,
    route,
    provider,
    model,
    window_unit,
    max_requests,
    max_input_tokens,
    max_output_tokens,
    max_total_tokens,
    max_estimated_cost_usd,
    enabled,
    updated_at
) VALUES (
    %(scope_type)s,
    %(strategy)s,
    %(route)s,
    %(provider)s,
    %(model)s,
    %(window_unit)s,
    %(max_requests)s,
    %(max_input_tokens)s,
    %(max_output_tokens)s,
    %(max_total_tokens)s,
    %(max_estimated_cost_usd)s,
    %(enabled)s,
    NOW()
)
ON CONFLICT (scope_type, route, provider, model, window_unit)
DO UPDATE SET
    strategy = EXCLUDED.strategy,
    max_requests = EXCLUDED.max_requests,
    max_input_tokens = EXCLUDED.max_input_tokens,
    max_output_tokens = EXCLUDED.max_output_tokens,
    max_total_tokens = EXCLUDED.max_total_tokens,
    max_estimated_cost_usd = EXCLUDED.max_estimated_cost_usd,
    enabled = EXCLUDED.enabled,
    updated_at = NOW()
RETURNING *
""".strip()

APPLICABLE_RATE_LIMIT_POLICIES_SELECT_SQL = """
SELECT
    id,
    scope_type,
    strategy,
    route,
    provider,
    model,
    window_unit,
    max_requests,
    max_input_tokens,
    max_output_tokens,
    max_total_tokens,
    max_estimated_cost_usd,
    enabled,
    created_at,
    updated_at
FROM rate_limit_policies
WHERE enabled = TRUE
  AND (route = %(route)s OR route = 'all')
  AND (provider = %(provider)s OR provider = '*')
  AND (model = %(model)s OR model = '*')
ORDER BY
    CASE window_unit
        WHEN 'minute' THEN 1
        WHEN 'hour' THEN 2
        ELSE 3
    END ASC,
    CASE scope_type
        WHEN 'route' THEN 1
        WHEN 'provider' THEN 2
        WHEN 'model' THEN 3
        ELSE 4
    END ASC,
    id ASC
""".strip()

RATE_LIMIT_BUCKET_SELECT_SQL = """
SELECT *
FROM rate_limit_buckets
WHERE policy_id = %(policy_id)s
  AND window_started_at = %(window_started_at)s
LIMIT 1
""".strip()


@dataclass(frozen=True)
class GovernanceRouteConfig:
    route: ProviderRoute
    enabled: bool
    exhausted_action: Literal["deny", "degrade"]
    request_limit_per_minute: int
    request_limit_per_hour: int
    daily_budget_usd: Decimal
    default_estimated_cost_usd: Decimal


@dataclass(frozen=True)
class PersistedRateLimitPolicy:
    id: int
    record: RateLimitPolicyRecord
    enabled: bool
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @classmethod
    def from_row(cls, row: dict[str, object]) -> "PersistedRateLimitPolicy":
        return cls(
            id=int(row["id"]),
            record=RateLimitPolicyRecord(
                scope_type=str(row["scope_type"]),
                strategy=str(row["strategy"]),
                route=str(row["route"]),
                provider=str(row["provider"]),
                model=str(row["model"]),
                window_unit=str(row["window_unit"]),
                max_requests=_normalize_optional_int(row.get("max_requests")),
                max_input_tokens=_normalize_optional_int(row.get("max_input_tokens")),
                max_output_tokens=_normalize_optional_int(row.get("max_output_tokens")),
                max_total_tokens=_normalize_optional_int(row.get("max_total_tokens")),
                max_estimated_cost_usd=_normalize_optional_decimal(row.get("max_estimated_cost_usd")),
            ),
            enabled=bool(row["enabled"]),
            created_at=_normalize_optional_datetime(row.get("created_at")),
            updated_at=_normalize_optional_datetime(row.get("updated_at")),
        )

    def key(self) -> tuple[str, str, str, str, str]:
        dimensions = self.record.normalized_dimensions()
        return (
            self.record.scope_type,
            dimensions.route,
            dimensions.provider,
            dimensions.model,
            self.record.window_unit,
        )


@dataclass(frozen=True)
class RateLimitBucketSnapshot:
    policy_id: int
    window_started_at: datetime
    window_ends_at: datetime
    request_count: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0
    estimated_cost_usd: Decimal = Decimal("0")
    deny_count: int = 0

    @classmethod
    def empty(
        cls,
        *,
        policy: PersistedRateLimitPolicy,
        occurred_at: datetime,
    ) -> "RateLimitBucketSnapshot":
        window_started_at = get_fixed_window_start(occurred_at, policy.record.window_unit)
        return cls(
            policy_id=policy.id,
            window_started_at=window_started_at,
            window_ends_at=get_fixed_window_end(window_started_at, policy.record.window_unit),
        )

    @classmethod
    def from_row(
        cls,
        row: dict[str, object] | None,
        *,
        policy: PersistedRateLimitPolicy,
        occurred_at: datetime,
    ) -> "RateLimitBucketSnapshot":
        if row is None:
            return cls.empty(policy=policy, occurred_at=occurred_at)

        return cls(
            policy_id=int(row["policy_id"]),
            window_started_at=_normalize_datetime(row["window_started_at"]),
            window_ends_at=_normalize_datetime(row["window_ends_at"]),
            request_count=int(row["request_count"]),
            input_tokens=int(row["input_tokens"]),
            output_tokens=int(row["output_tokens"]),
            total_tokens=int(row["total_tokens"]),
            estimated_cost_usd=_normalize_decimal(row["estimated_cost_usd"]),
            deny_count=int(row["deny_count"]),
        )


@dataclass(frozen=True)
class GovernanceDecision:
    allowed: bool
    action: GovernanceAction
    route: ProviderRoute
    provider: str
    model: str
    code: str | None = None
    message: str | None = None
    status_code: int | None = None
    details: dict[str, Any] = field(default_factory=dict)

    @property
    def fallback_allowed(self) -> bool:
        return self.action == "degrade"

    def raise_for_violation(self) -> None:
        if self.allowed:
            return

        raise GovernancePolicyError(
            code=self.code or "governance_blocked",
            message=self.message or "The request is blocked by governance policy.",
            status_code=self.status_code or 429,
            details=self.details,
            retryable=False,
        )


@dataclass(frozen=True)
class GovernanceRouteStatus:
    route: ProviderRoute
    enabled: bool
    exhausted_action: Literal["deny", "degrade"]
    request_limit_per_minute: int
    request_limit_per_hour: int
    daily_budget_usd: Decimal
    projected_next_request_cost_usd: Decimal
    budget_status: GovernanceBudgetStatus
    spent_budget_usd: Decimal | None = None
    remaining_budget_usd: Decimal | None = None
    utilization_ratio: Decimal | None = None
    next_request_would_exhaust_budget: bool | None = None


def build_governance_route_configs(settings: Settings) -> tuple[GovernanceRouteConfig, ...]:
    return (
        GovernanceRouteConfig(
            route=INTERPRET_ROUTE,
            enabled=True,
            exhausted_action=_normalize_action(settings.interpretation_exhausted_action, default="deny"),
            request_limit_per_minute=max(0, settings.interpretation_requests_per_minute),
            request_limit_per_hour=max(0, settings.interpretation_requests_per_hour),
            daily_budget_usd=max(Decimal("0"), settings.interpretation_daily_budget_usd),
            default_estimated_cost_usd=max(
                Decimal("0"),
                settings.interpretation_default_estimated_cost_usd,
            ),
        ),
        GovernanceRouteConfig(
            route=RESPOND_ROUTE,
            enabled=settings.delivery_route_enabled,
            exhausted_action=_normalize_action(settings.delivery_exhausted_action, default="degrade"),
            request_limit_per_minute=max(0, settings.delivery_requests_per_minute),
            request_limit_per_hour=max(0, settings.delivery_requests_per_hour),
            daily_budget_usd=max(Decimal("0"), settings.delivery_daily_budget_usd),
            default_estimated_cost_usd=max(
                Decimal("0"),
                settings.delivery_default_estimated_cost_usd,
            ),
        ),
    )


def build_default_governance_policies(settings: Settings) -> tuple[RateLimitPolicyRecord, ...]:
    policies: list[RateLimitPolicyRecord] = []

    for route_config in build_governance_route_configs(settings):
        policies.extend(
            [
                RateLimitPolicyRecord(
                    scope_type="route",
                    window_unit="minute",
                    route=route_config.route,
                    max_requests=route_config.request_limit_per_minute,
                ),
                RateLimitPolicyRecord(
                    scope_type="route",
                    window_unit="hour",
                    route=route_config.route,
                    max_requests=route_config.request_limit_per_hour,
                ),
                RateLimitPolicyRecord(
                    scope_type="route",
                    window_unit="day",
                    route=route_config.route,
                    max_estimated_cost_usd=route_config.daily_budget_usd,
                ),
            ]
        )

    return tuple(policies)


class AdapterGovernanceService:
    def __init__(
        self,
        settings: Settings | None = None,
        pool: ConnectionPool | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.pool = pool
        self._default_policies: dict[tuple[str, str, str, str, str], PersistedRateLimitPolicy] = {}

    def route_config(self, route: ProviderRoute) -> GovernanceRouteConfig:
        route_configs = {
            config.route: config
            for config in build_governance_route_configs(self.settings)
        }
        return route_configs[route]

    def sync_default_policies(
        self,
        *,
        connection: psycopg.Connection | None = None,
    ) -> tuple[PersistedRateLimitPolicy, ...]:
        with self._connection_scope(connection) as active_connection:
            persisted_policies: dict[tuple[str, str, str, str, str], PersistedRateLimitPolicy] = {}

            with active_connection.cursor(row_factory=dict_row) as cursor:
                for record in build_default_governance_policies(self.settings):
                    cursor.execute(
                        RATE_LIMIT_POLICY_UPSERT_SQL,
                        _build_policy_upsert_params(record, enabled=True),
                    )
                    row = cursor.fetchone()

                    if row is None:
                        raise RuntimeError("Rate-limit policy upsert did not return a row.")

                    policy = PersistedRateLimitPolicy.from_row(row)
                    persisted_policies[policy.key()] = policy

            self._default_policies = persisted_policies
            return tuple(persisted_policies.values())

    def preflight_check(
        self,
        *,
        route: ProviderRoute,
        provider: str,
        model: str,
        request_id: str,
        generation_id: str,
        estimated_cost_usd: Decimal | None = None,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> GovernanceDecision:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))
        route_config = self.route_config(route)

        if not route_config.enabled:
            return GovernanceDecision(
                allowed=False,
                action=route_config.exhausted_action,
                route=route,
                provider=_normalize_dimension(provider),
                model=_normalize_dimension(model),
                code="delivery_route_disabled",
                message="Delivery route is temporarily disabled; use backend fallback handling.",
                status_code=503,
                details={
                    "action": route_config.exhausted_action,
                    "fallback_allowed": route_config.exhausted_action == "degrade",
                    "route": route,
                    "provider": _normalize_dimension(provider),
                    "model": _normalize_dimension(model),
                    "reason": "route_disabled",
                },
            )

        projected_cost = _normalize_decimal(
            estimated_cost_usd
            if estimated_cost_usd is not None
            else route_config.default_estimated_cost_usd
        )

        with self._connection_scope(connection) as active_connection:
            self._ensure_default_policies(active_connection)
            policies = self._fetch_applicable_policies(
                route=route,
                provider=provider,
                model=model,
                connection=active_connection,
            )

            for policy in policies:
                bucket = self._fetch_bucket_snapshot(
                    policy,
                    occurred_at=current_time,
                    connection=active_connection,
                )
                decision = _evaluate_policy_decision(
                    policy=policy,
                    bucket=bucket,
                    route_config=route_config,
                    route=route,
                    provider=provider,
                    model=model,
                    projected_estimated_cost_usd=projected_cost,
                )

                if decision is None:
                    continue

                self.record_denial(
                    route=route,
                    provider=provider,
                    model=model,
                    request_id=request_id,
                    generation_id=generation_id,
                    policy=policy,
                    now=current_time,
                    connection=active_connection,
                )
                return decision

        return GovernanceDecision(
            allowed=True,
            action="allow",
            route=route,
            provider=_normalize_dimension(provider),
            model=_normalize_dimension(model),
        )

    def record_usage(
        self,
        *,
        route: ProviderRoute,
        provider: str,
        model: str,
        request_id: str,
        generation_id: str,
        usage: ProviderUsage | None = None,
        estimated_cost_usd: Decimal | None = None,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> tuple[RateLimitBucketSnapshot, ...]:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))
        route_config = self.route_config(route)
        normalized_usage = usage or ProviderUsage(
            input_tokens=0,
            output_tokens=0,
            total_tokens=0,
            latency_ms=None,
            upstream_request_id=None,
            finish_reason=None,
        )
        normalized_estimated_cost = _normalize_decimal(
            estimated_cost_usd
            if estimated_cost_usd is not None
            else route_config.default_estimated_cost_usd
        )

        with self._connection_scope(connection) as active_connection:
            self._ensure_default_policies(active_connection)
            policies = self._fetch_applicable_policies(
                route=route,
                provider=provider,
                model=model,
                connection=active_connection,
            )
            updated_buckets: list[RateLimitBucketSnapshot] = []

            for policy in policies:
                mutation = RateLimitBucketMutation.from_policy_and_usage(
                    policy_id=policy.id,
                    policy=policy.record,
                    usage=normalized_usage,
                    estimated_cost_usd=normalized_estimated_cost,
                    last_request_id=request_id,
                    last_generation_id=generation_id,
                )
                updated_buckets.append(
                    self._upsert_bucket(
                        mutation,
                        occurred_at=current_time,
                        connection=active_connection,
                        policy=policy,
                    )
                )

            return tuple(updated_buckets)

    def record_denial(
        self,
        *,
        route: ProviderRoute,
        provider: str,
        model: str,
        request_id: str,
        generation_id: str,
        policy: PersistedRateLimitPolicy,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> RateLimitBucketSnapshot:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))
        dimensions = policy.record.normalized_dimensions()
        mutation = RateLimitBucketMutation(
            policy_id=policy.id,
            scope_type=policy.record.scope_type,
            window_unit=policy.record.window_unit,
            route=dimensions.route,
            provider=dimensions.provider,
            model=dimensions.model,
            request_count=0,
            input_tokens=0,
            output_tokens=0,
            total_tokens=0,
            estimated_cost_usd=Decimal("0"),
            deny_count=1,
            last_request_id=request_id,
            last_generation_id=generation_id,
        )

        with self._connection_scope(connection) as active_connection:
            return self._upsert_bucket(
                mutation,
                occurred_at=current_time,
                connection=active_connection,
                policy=policy,
            )

    def budget_statuses(
        self,
        *,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> tuple[GovernanceRouteStatus, ...]:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))

        with self._connection_scope(connection) as active_connection:
            persisted_default_policies = {
                policy.key(): policy
                for policy in self.sync_default_policies(connection=active_connection)
            }

            statuses: list[GovernanceRouteStatus] = []
            for route_config in build_governance_route_configs(self.settings):
                policy_key = (
                    "route",
                    route_config.route,
                    RATE_LIMIT_DIMENSION_ALL,
                    RATE_LIMIT_DIMENSION_ALL,
                    "day",
                )
                policy = persisted_default_policies.get(policy_key)
                if policy is None:
                    statuses.append(
                        GovernanceRouteStatus(
                            route=route_config.route,
                            enabled=route_config.enabled,
                            exhausted_action=route_config.exhausted_action,
                            request_limit_per_minute=route_config.request_limit_per_minute,
                            request_limit_per_hour=route_config.request_limit_per_hour,
                            daily_budget_usd=route_config.daily_budget_usd,
                            projected_next_request_cost_usd=route_config.default_estimated_cost_usd,
                            budget_status="disabled" if not route_config.enabled else "unavailable",
                        )
                    )
                    continue

                bucket = self._fetch_bucket_snapshot(
                    policy,
                    occurred_at=current_time,
                    connection=active_connection,
                )
                statuses.append(
                    _build_route_status(
                        route_config=route_config,
                        bucket=bucket,
                        budget_warning_ratio=self.settings.budget_warning_ratio,
                    )
                )

            return tuple(statuses)

    def _ensure_default_policies(self, connection: psycopg.Connection) -> tuple[PersistedRateLimitPolicy, ...]:
        if self._default_policies:
            return tuple(self._default_policies.values())

        return self.sync_default_policies(connection=connection)

    def _fetch_applicable_policies(
        self,
        *,
        route: ProviderRoute,
        provider: str,
        model: str,
        connection: psycopg.Connection,
    ) -> tuple[PersistedRateLimitPolicy, ...]:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                APPLICABLE_RATE_LIMIT_POLICIES_SELECT_SQL,
                {
                    "route": _normalize_route(route),
                    "provider": _normalize_dimension(provider),
                    "model": _normalize_dimension(model),
                },
            )
            rows = cursor.fetchall()

        return tuple(PersistedRateLimitPolicy.from_row(row) for row in rows)

    def _fetch_bucket_snapshot(
        self,
        policy: PersistedRateLimitPolicy,
        *,
        occurred_at: datetime,
        connection: psycopg.Connection,
    ) -> RateLimitBucketSnapshot:
        window_started_at = get_fixed_window_start(occurred_at, policy.record.window_unit)

        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                RATE_LIMIT_BUCKET_SELECT_SQL,
                {
                    "policy_id": policy.id,
                    "window_started_at": window_started_at,
                },
            )
            row = cursor.fetchone()

        return RateLimitBucketSnapshot.from_row(row, policy=policy, occurred_at=occurred_at)

    def _upsert_bucket(
        self,
        mutation: RateLimitBucketMutation,
        *,
        occurred_at: datetime,
        connection: psycopg.Connection,
        policy: PersistedRateLimitPolicy,
    ) -> RateLimitBucketSnapshot:
        params = build_rate_limit_bucket_params(mutation, occurred_at=occurred_at)

        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(RATE_LIMIT_BUCKET_UPSERT_SQL, params)
            row = cursor.fetchone()

        return RateLimitBucketSnapshot.from_row(row, policy=policy, occurred_at=occurred_at)

    @contextmanager
    def _connection_scope(self, connection: psycopg.Connection | None):
        if connection is not None:
            yield connection
            return

        if self.settings.database_url == "":
            raise RuntimeError("LLM_ADAPTER_DATABASE_URL is not configured.")

        if self.pool is not None:
            with self.pool.connection() as pooled_connection:
                yield pooled_connection
            return

        with psycopg.connect(
            self.settings.database_url,
            autocommit=False,
            connect_timeout=self.settings.database_connect_timeout_seconds,
        ) as direct_connection:
            yield direct_connection


def build_governance_health_payload(
    settings: Settings,
    *,
    postgres_ready: bool,
) -> dict[str, object]:
    route_configs = build_governance_route_configs(settings)

    if not postgres_ready:
        return {
            "ready": False,
            "budget_warning_ratio": float(settings.budget_warning_ratio),
            "routes": [
                _route_status_payload(
                    GovernanceRouteStatus(
                        route=config.route,
                        enabled=config.enabled,
                        exhausted_action=config.exhausted_action,
                        request_limit_per_minute=config.request_limit_per_minute,
                        request_limit_per_hour=config.request_limit_per_hour,
                        daily_budget_usd=config.daily_budget_usd,
                        projected_next_request_cost_usd=config.default_estimated_cost_usd,
                        budget_status="disabled" if not config.enabled else "unavailable",
                    )
                )
                for config in route_configs
            ],
            "error": None,
        }

    try:
        service = AdapterGovernanceService(settings=settings)
        route_statuses = service.budget_statuses()
        return {
            "ready": True,
            "budget_warning_ratio": float(settings.budget_warning_ratio),
            "routes": [_route_status_payload(status) for status in route_statuses],
            "error": None,
        }
    except Exception as exc:
        return {
            "ready": False,
            "budget_warning_ratio": float(settings.budget_warning_ratio),
            "routes": [
                _route_status_payload(
                    GovernanceRouteStatus(
                        route=config.route,
                        enabled=config.enabled,
                        exhausted_action=config.exhausted_action,
                        request_limit_per_minute=config.request_limit_per_minute,
                        request_limit_per_hour=config.request_limit_per_hour,
                        daily_budget_usd=config.daily_budget_usd,
                        projected_next_request_cost_usd=config.default_estimated_cost_usd,
                        budget_status="disabled" if not config.enabled else "unavailable",
                    )
                )
                for config in route_configs
            ],
            "error": {
                "code": "governance_unavailable",
                "message": "Could not summarize governance budget status.",
                "detail": exc.__class__.__name__,
            },
        }


def _build_policy_upsert_params(
    record: RateLimitPolicyRecord,
    *,
    enabled: bool,
) -> dict[str, object]:
    dimensions = record.normalized_dimensions()

    return {
        "scope_type": record.scope_type,
        "strategy": record.strategy,
        "route": dimensions.route,
        "provider": dimensions.provider,
        "model": dimensions.model,
        "window_unit": record.window_unit,
        "max_requests": record.max_requests,
        "max_input_tokens": record.max_input_tokens,
        "max_output_tokens": record.max_output_tokens,
        "max_total_tokens": record.max_total_tokens,
        "max_estimated_cost_usd": record.max_estimated_cost_usd,
        "enabled": enabled,
    }


def _evaluate_policy_decision(
    *,
    policy: PersistedRateLimitPolicy,
    bucket: RateLimitBucketSnapshot,
    route_config: GovernanceRouteConfig,
    route: ProviderRoute,
    provider: str,
    model: str,
    projected_estimated_cost_usd: Decimal,
) -> GovernanceDecision | None:
    if policy.record.max_requests is not None:
        current_requests = bucket.request_count
        projected_requests = current_requests + 1

        if projected_requests > policy.record.max_requests:
            return _blocked_policy_decision(
                route=route,
                provider=provider,
                model=model,
                route_config=route_config,
                policy=policy,
                bucket=bucket,
                code="route_rate_limited",
                message="The adapter route quota has been exhausted.",
                metric="requests",
                current_value=current_requests,
                projected_value=projected_requests,
                ceiling_value=policy.record.max_requests,
                reason="rate_limit_exceeded",
            )

    if policy.record.max_estimated_cost_usd is not None:
        current_cost = bucket.estimated_cost_usd
        projected_cost = current_cost + projected_estimated_cost_usd

        if projected_cost > policy.record.max_estimated_cost_usd:
            return _blocked_policy_decision(
                route=route,
                provider=provider,
                model=model,
                route_config=route_config,
                policy=policy,
                bucket=bucket,
                code="route_budget_exhausted",
                message="The adapter daily budget has been exhausted for this route.",
                metric="estimated_cost_usd",
                current_value=_format_decimal(current_cost),
                projected_value=_format_decimal(projected_cost),
                ceiling_value=_format_decimal(policy.record.max_estimated_cost_usd),
                reason="budget_exhausted",
            )

    return None


def _blocked_policy_decision(
    *,
    route: ProviderRoute,
    provider: str,
    model: str,
    route_config: GovernanceRouteConfig,
    policy: PersistedRateLimitPolicy,
    bucket: RateLimitBucketSnapshot,
    code: str,
    message: str,
    metric: str,
    current_value: str | int,
    projected_value: str | int,
    ceiling_value: str | int,
    reason: str,
) -> GovernanceDecision:
    normalized_provider = _normalize_dimension(provider)
    normalized_model = _normalize_dimension(model)

    return GovernanceDecision(
        allowed=False,
        action=route_config.exhausted_action,
        route=route,
        provider=normalized_provider,
        model=normalized_model,
        code=code,
        message=message,
        status_code=429,
        details={
            "action": route_config.exhausted_action,
            "fallback_allowed": route_config.exhausted_action == "degrade",
            "route": route,
            "provider": normalized_provider,
            "model": normalized_model,
            "policy_id": policy.id,
            "scope_type": policy.record.scope_type,
            "window_unit": policy.record.window_unit,
            "metric": metric,
            "current_value": current_value,
            "projected_value": projected_value,
            "ceiling_value": ceiling_value,
            "window_started_at": bucket.window_started_at.isoformat(),
            "window_ends_at": bucket.window_ends_at.isoformat(),
            "reason": reason,
        },
    )


def _build_route_status(
    *,
    route_config: GovernanceRouteConfig,
    bucket: RateLimitBucketSnapshot,
    budget_warning_ratio: Decimal,
) -> GovernanceRouteStatus:
    spent_budget_usd = bucket.estimated_cost_usd
    remaining_budget_usd = max(Decimal("0"), route_config.daily_budget_usd - spent_budget_usd)
    next_request_would_exhaust_budget = (
        spent_budget_usd + route_config.default_estimated_cost_usd
    ) > route_config.daily_budget_usd
    utilization_ratio = Decimal("0")

    if route_config.daily_budget_usd > Decimal("0"):
        utilization_ratio = spent_budget_usd / route_config.daily_budget_usd

    if not route_config.enabled:
        budget_status: GovernanceBudgetStatus = "disabled"
    elif route_config.daily_budget_usd <= Decimal("0"):
        budget_status = "exhausted"
    elif spent_budget_usd >= route_config.daily_budget_usd:
        budget_status = "exhausted"
    elif utilization_ratio >= budget_warning_ratio or next_request_would_exhaust_budget:
        budget_status = "warning"
    else:
        budget_status = "healthy"

    return GovernanceRouteStatus(
        route=route_config.route,
        enabled=route_config.enabled,
        exhausted_action=route_config.exhausted_action,
        request_limit_per_minute=route_config.request_limit_per_minute,
        request_limit_per_hour=route_config.request_limit_per_hour,
        daily_budget_usd=route_config.daily_budget_usd,
        projected_next_request_cost_usd=route_config.default_estimated_cost_usd,
        budget_status=budget_status,
        spent_budget_usd=spent_budget_usd,
        remaining_budget_usd=remaining_budget_usd,
        utilization_ratio=utilization_ratio,
        next_request_would_exhaust_budget=next_request_would_exhaust_budget,
    )


def _route_status_payload(status: GovernanceRouteStatus) -> dict[str, object]:
    return {
        "route": status.route,
        "enabled": status.enabled,
        "exhausted_action": status.exhausted_action,
        "request_limit_per_minute": status.request_limit_per_minute,
        "request_limit_per_hour": status.request_limit_per_hour,
        "daily_budget_usd": _format_decimal(status.daily_budget_usd),
        "spent_budget_usd": _format_optional_decimal(status.spent_budget_usd),
        "remaining_budget_usd": _format_optional_decimal(status.remaining_budget_usd),
        "projected_next_request_cost_usd": _format_decimal(status.projected_next_request_cost_usd),
        "utilization_ratio": float(status.utilization_ratio) if status.utilization_ratio is not None else None,
        "budget_status": status.budget_status,
        "next_request_would_exhaust_budget": status.next_request_would_exhaust_budget,
    }


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


def _normalize_optional_int(value: object | None) -> int | None:
    if value is None:
        return None

    return int(value)


def _normalize_dimension(value: str) -> str:
    normalized = value.strip().lower()
    return normalized or RATE_LIMIT_DIMENSION_ALL


def _normalize_route(value: str) -> str:
    normalized = value.strip().lower()
    return normalized or RATE_LIMIT_ROUTE_ALL


def _normalize_decimal(value: Decimal | object) -> Decimal:
    if isinstance(value, Decimal):
        return value

    return Decimal(str(value))


def _normalize_optional_decimal(value: object | None) -> Decimal | None:
    if value is None:
        return None

    return _normalize_decimal(value)


def _normalize_action(value: str, *, default: Literal["deny", "degrade"]) -> Literal["deny", "degrade"]:
    normalized = value.strip().lower()

    if normalized in {"deny", "degrade"}:
        return normalized

    return default


def _format_decimal(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.00000001'))}"


def _format_optional_decimal(value: Decimal | None) -> str | None:
    if value is None:
        return None

    return _format_decimal(value)