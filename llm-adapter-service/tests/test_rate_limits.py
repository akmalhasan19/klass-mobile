from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal

from app.providers.base import ProviderUsage
from app.rate_limits import (
    RATE_LIMIT_BUCKET_UPSERT_SQL,
    RateLimitBucketMutation,
    RateLimitPolicyRecord,
    build_rate_limit_bucket_params,
)


def test_rate_limit_policy_normalizes_provider_daily_budget_dimensions() -> None:
    policy = RateLimitPolicyRecord(
        scope_type="provider",
        window_unit="day",
        provider="Gemini",
        max_estimated_cost_usd=Decimal("25.00"),
    )

    dimensions = policy.normalized_dimensions()

    assert dimensions.route == "all"
    assert dimensions.provider == "gemini"
    assert dimensions.model == "*"


def test_build_rate_limit_bucket_params_uses_fixed_window_boundaries() -> None:
    policy = RateLimitPolicyRecord(
        scope_type="model",
        window_unit="minute",
        route="interpret",
        provider="gemini",
        model="gemini-2.0-flash",
        max_requests=120,
    )
    usage = ProviderUsage(
        input_tokens=120,
        output_tokens=40,
        total_tokens=160,
        latency_ms=42.5,
        upstream_request_id="upstream-1",
        finish_reason="stop",
    )
    mutation = RateLimitBucketMutation.from_policy_and_usage(
        policy_id=42,
        policy=policy,
        usage=usage,
        estimated_cost_usd=Decimal("0.015"),
        last_request_id="req-42",
        last_generation_id="gen-42",
    )

    params = build_rate_limit_bucket_params(
        mutation,
        occurred_at=datetime(2026, 4, 9, 10, 44, 15, 123456, tzinfo=timezone.utc),
    )

    assert params["policy_id"] == 42
    assert params["route"] == "interpret"
    assert params["provider"] == "gemini"
    assert params["model"] == "gemini-2.0-flash"
    assert params["window_started_at"] == datetime(2026, 4, 9, 10, 44, 0, tzinfo=timezone.utc)
    assert params["window_ends_at"] == datetime(2026, 4, 9, 10, 45, 0, tzinfo=timezone.utc)
    assert params["input_tokens"] == 120
    assert params["output_tokens"] == 40
    assert params["total_tokens"] == 160
    assert params["estimated_cost_usd"] == Decimal("0.015")


def test_rate_limit_bucket_upsert_sql_uses_atomic_conflict_update() -> None:
    assert "ON CONFLICT (policy_id, window_started_at)" in RATE_LIMIT_BUCKET_UPSERT_SQL
    assert (
        "request_count = rate_limit_buckets.request_count + EXCLUDED.request_count"
        in RATE_LIMIT_BUCKET_UPSERT_SQL
    )
    assert (
        "estimated_cost_usd = rate_limit_buckets.estimated_cost_usd + EXCLUDED.estimated_cost_usd"
        in RATE_LIMIT_BUCKET_UPSERT_SQL
    )