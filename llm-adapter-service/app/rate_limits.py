from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Literal

from app.providers.base import ProviderUsage

RateLimitScopeType = Literal["global", "provider", "model", "route"]
RateLimitWindowUnit = Literal["minute", "hour", "day"]

RATE_LIMIT_DIMENSION_ALL = "*"
RATE_LIMIT_ROUTE_ALL = "all"
RATE_LIMIT_FIXED_WINDOW = "fixed_window"


@dataclass(frozen=True)
class RateLimitDimensions:
    route: str
    provider: str
    model: str


@dataclass(frozen=True)
class RateLimitPolicyRecord:
    scope_type: RateLimitScopeType
    window_unit: RateLimitWindowUnit
    max_requests: int | None = None
    max_input_tokens: int | None = None
    max_output_tokens: int | None = None
    max_total_tokens: int | None = None
    max_estimated_cost_usd: Decimal | None = None
    route: str = RATE_LIMIT_ROUTE_ALL
    provider: str = RATE_LIMIT_DIMENSION_ALL
    model: str = RATE_LIMIT_DIMENSION_ALL
    strategy: str = RATE_LIMIT_FIXED_WINDOW

    def __post_init__(self) -> None:
        if self.strategy != RATE_LIMIT_FIXED_WINDOW:
            raise ValueError("Only fixed_window rate limiting is supported.")

        if self.window_unit not in {"minute", "hour", "day"}:
            raise ValueError("Unsupported rate-limit window unit.")

        if all(
            value is None
            for value in [
                self.max_requests,
                self.max_input_tokens,
                self.max_output_tokens,
                self.max_total_tokens,
                self.max_estimated_cost_usd,
            ]
        ):
            raise ValueError("A rate-limit policy requires at least one ceiling.")

        if self.scope_type == "route" and _normalize_route(self.route) == RATE_LIMIT_ROUTE_ALL:
            raise ValueError("Route-scoped policies require a concrete route.")

        if self.scope_type == "provider" and _normalize_dimension(self.provider) == RATE_LIMIT_DIMENSION_ALL:
            raise ValueError("Provider-scoped policies require a concrete provider.")

        if self.scope_type == "model" and _normalize_dimension(self.model) == RATE_LIMIT_DIMENSION_ALL:
            raise ValueError("Model-scoped policies require a concrete model.")

    def normalized_dimensions(self) -> RateLimitDimensions:
        route = _normalize_route(self.route)
        provider = _normalize_dimension(self.provider)
        model = _normalize_dimension(self.model)

        if self.scope_type == "global":
            return RateLimitDimensions(
                route=RATE_LIMIT_ROUTE_ALL,
                provider=RATE_LIMIT_DIMENSION_ALL,
                model=RATE_LIMIT_DIMENSION_ALL,
            )

        if self.scope_type == "route":
            return RateLimitDimensions(
                route=route,
                provider=RATE_LIMIT_DIMENSION_ALL,
                model=RATE_LIMIT_DIMENSION_ALL,
            )

        if self.scope_type == "provider":
            return RateLimitDimensions(
                route=route,
                provider=provider,
                model=RATE_LIMIT_DIMENSION_ALL,
            )

        return RateLimitDimensions(route=route, provider=provider, model=model)


@dataclass(frozen=True)
class RateLimitBucketMutation:
    policy_id: int
    scope_type: RateLimitScopeType
    window_unit: RateLimitWindowUnit
    route: str
    provider: str
    model: str
    request_count: int = 1
    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0
    estimated_cost_usd: Decimal = Decimal("0")
    deny_count: int = 0
    last_request_id: str | None = None
    last_generation_id: str | None = None
    strategy: str = RATE_LIMIT_FIXED_WINDOW

    @classmethod
    def from_policy_and_usage(
        cls,
        *,
        policy_id: int,
        policy: RateLimitPolicyRecord,
        usage: ProviderUsage | None,
        estimated_cost_usd: Decimal | None = None,
        last_request_id: str | None = None,
        last_generation_id: str | None = None,
        deny_count: int = 0,
    ) -> "RateLimitBucketMutation":
        dimensions = policy.normalized_dimensions()

        return cls(
            policy_id=policy_id,
            scope_type=policy.scope_type,
            window_unit=policy.window_unit,
            route=dimensions.route,
            provider=dimensions.provider,
            model=dimensions.model,
            request_count=1,
            input_tokens=max(0, usage.input_tokens or 0) if usage is not None else 0,
            output_tokens=max(0, usage.output_tokens or 0) if usage is not None else 0,
            total_tokens=max(0, usage.total_tokens or 0) if usage is not None else 0,
            estimated_cost_usd=estimated_cost_usd or Decimal("0"),
            deny_count=max(0, deny_count),
            last_request_id=last_request_id,
            last_generation_id=last_generation_id,
        )


RATE_LIMIT_BUCKET_UPSERT_SQL = """
INSERT INTO rate_limit_buckets (
    policy_id,
    scope_type,
    strategy,
    route,
    provider,
    model,
    window_unit,
    window_started_at,
    window_ends_at,
    request_count,
    input_tokens,
    output_tokens,
    total_tokens,
    estimated_cost_usd,
    deny_count,
    last_request_id,
    last_generation_id,
    last_seen_at,
    updated_at
) VALUES (
    %(policy_id)s,
    %(scope_type)s,
    %(strategy)s,
    %(route)s,
    %(provider)s,
    %(model)s,
    %(window_unit)s,
    %(window_started_at)s,
    %(window_ends_at)s,
    %(request_count)s,
    %(input_tokens)s,
    %(output_tokens)s,
    %(total_tokens)s,
    %(estimated_cost_usd)s,
    %(deny_count)s,
    %(last_request_id)s,
    %(last_generation_id)s,
    %(last_seen_at)s,
    NOW()
)
ON CONFLICT (policy_id, window_started_at)
DO UPDATE SET
    request_count = rate_limit_buckets.request_count + EXCLUDED.request_count,
    input_tokens = rate_limit_buckets.input_tokens + EXCLUDED.input_tokens,
    output_tokens = rate_limit_buckets.output_tokens + EXCLUDED.output_tokens,
    total_tokens = rate_limit_buckets.total_tokens + EXCLUDED.total_tokens,
    estimated_cost_usd = rate_limit_buckets.estimated_cost_usd + EXCLUDED.estimated_cost_usd,
    deny_count = rate_limit_buckets.deny_count + EXCLUDED.deny_count,
    last_request_id = COALESCE(EXCLUDED.last_request_id, rate_limit_buckets.last_request_id),
    last_generation_id = COALESCE(EXCLUDED.last_generation_id, rate_limit_buckets.last_generation_id),
    last_seen_at = GREATEST(rate_limit_buckets.last_seen_at, EXCLUDED.last_seen_at),
    updated_at = NOW()
RETURNING *
""".strip()


def build_rate_limit_bucket_params(
    mutation: RateLimitBucketMutation,
    *,
    occurred_at: datetime,
) -> dict[str, object]:
    window_started_at = get_fixed_window_start(occurred_at, mutation.window_unit)
    window_ends_at = get_fixed_window_end(window_started_at, mutation.window_unit)
    normalized_occurred_at = _normalize_datetime(occurred_at)

    return {
        "policy_id": mutation.policy_id,
        "scope_type": mutation.scope_type,
        "strategy": mutation.strategy,
        "route": _normalize_route(mutation.route),
        "provider": _normalize_dimension(mutation.provider),
        "model": _normalize_dimension(mutation.model),
        "window_unit": mutation.window_unit,
        "window_started_at": window_started_at,
        "window_ends_at": window_ends_at,
        "request_count": max(0, mutation.request_count),
        "input_tokens": max(0, mutation.input_tokens),
        "output_tokens": max(0, mutation.output_tokens),
        "total_tokens": max(0, mutation.total_tokens),
        "estimated_cost_usd": mutation.estimated_cost_usd,
        "deny_count": max(0, mutation.deny_count),
        "last_request_id": _normalize_optional_string(mutation.last_request_id),
        "last_generation_id": _normalize_optional_string(mutation.last_generation_id),
        "last_seen_at": normalized_occurred_at,
    }


def get_fixed_window_start(
    occurred_at: datetime,
    window_unit: RateLimitWindowUnit,
) -> datetime:
    normalized_occurred_at = _normalize_datetime(occurred_at)

    if window_unit == "minute":
        return normalized_occurred_at.replace(second=0, microsecond=0)

    if window_unit == "hour":
        return normalized_occurred_at.replace(minute=0, second=0, microsecond=0)

    if window_unit == "day":
        return normalized_occurred_at.replace(hour=0, minute=0, second=0, microsecond=0)

    raise ValueError("Unsupported fixed-window unit.")


def get_fixed_window_end(
    window_started_at: datetime,
    window_unit: RateLimitWindowUnit,
) -> datetime:
    if window_unit == "minute":
        return window_started_at + timedelta(minutes=1)

    if window_unit == "hour":
        return window_started_at + timedelta(hours=1)

    if window_unit == "day":
        return window_started_at + timedelta(days=1)

    raise ValueError("Unsupported fixed-window unit.")


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value.astimezone(timezone.utc)


def _normalize_route(value: str) -> str:
    normalized = (value or "").strip().lower()
    return normalized or RATE_LIMIT_ROUTE_ALL


def _normalize_dimension(value: str) -> str:
    normalized = (value or "").strip().lower()
    return normalized or RATE_LIMIT_DIMENSION_ALL


def _normalize_optional_string(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip()
    return normalized or None