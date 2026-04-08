from __future__ import annotations

from decimal import Decimal

from app.costs import (
    ACTIVE_PRICE_CATALOG_LOOKUP_SQL,
    DAILY_AGGREGATES_SELECT_SQL,
    DAILY_ROUTE_AGGREGATES_SELECT_SQL,
    PriceCatalogEntry,
    build_ledger_entry_from_execution_result,
    estimate_usage_cost,
)
from app.providers.base import (
    ProviderCompletion,
    ProviderExecutionResult,
    ProviderResponseReference,
    ProviderUsage,
)


def test_estimate_usage_cost_combines_request_input_and_output_pricing() -> None:
    entry = PriceCatalogEntry(
        provider="gemini",
        model="gemini-2.0-flash",
        input_cost_per_unit_usd=Decimal("0.00125"),
        output_cost_per_unit_usd=Decimal("0.005"),
        request_cost_usd=Decimal("0.002"),
    )
    usage = ProviderUsage(
        input_tokens=1200,
        output_tokens=300,
        total_tokens=1500,
        latency_ms=25.0,
        upstream_request_id="goog-1",
        finish_reason="stop",
    )

    estimated_cost = estimate_usage_cost(usage, entry)

    assert estimated_cost == Decimal("0.00500000")


def test_build_ledger_entry_from_execution_result_preserves_fallback_and_cost_metadata() -> None:
    usage = ProviderUsage(
        input_tokens=1000,
        output_tokens=500,
        total_tokens=1500,
        latency_ms=88.2,
        upstream_request_id="openai-req-1",
        finish_reason="completed",
    )
    completion = ProviderCompletion(
        provider="openai",
        route="interpret",
        generation_id="gen-500",
        requested_model="llm-gateway",
        model="gpt-5.4",
        raw_completion='{"schema_version":"media_prompt_understanding.v1"}',
        usage=usage,
        response_reference=ProviderResponseReference(
            response_id="resp-500",
            model_version="gpt-5.4",
            candidate_index=0,
        ),
        raw_response={"id": "resp-500"},
    )
    result = ProviderExecutionResult(
        completion=completion,
        primary_provider="gemini",
        fallback_used=True,
        fallback_reason="provider_rate_limited",
        attempted_providers=("gemini", "openai"),
    )
    price_entry = PriceCatalogEntry(
        provider="openai",
        model="gpt-5.4",
        input_cost_per_unit_usd=Decimal("0.002"),
        output_cost_per_unit_usd=Decimal("0.004"),
    )

    ledger_entry = build_ledger_entry_from_execution_result(
        request_id="req-500",
        request_type="media_prompt_interpretation",
        result=result,
        retry_count=1,
        cache_status="miss",
        final_status="success",
        price_catalog_entry=price_entry,
        cache_key="a" * 64,
        metadata={"source": "unit-test"},
    )

    assert ledger_entry.provider == "openai"
    assert ledger_entry.primary_provider == "gemini"
    assert ledger_entry.retry_count == 1
    assert ledger_entry.fallback_used is True
    assert ledger_entry.fallback_reason == "provider_rate_limited"
    assert ledger_entry.estimated_cost_usd == Decimal("0.00400000")
    assert ledger_entry.cache_key == "a" * 64
    assert ledger_entry.as_record()["attempted_providers"] == ["gemini", "openai"]


def test_cost_queries_target_price_catalog_and_daily_views() -> None:
    assert "FROM price_catalog_entries" in ACTIVE_PRICE_CATALOG_LOOKUP_SQL
    assert "FROM llm_request_daily_aggregates" in DAILY_AGGREGATES_SELECT_SQL
    assert "FROM llm_request_daily_route_aggregates" in DAILY_ROUTE_AGGREGATES_SELECT_SQL