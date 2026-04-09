from __future__ import annotations

from decimal import Decimal

from app.costs import AdapterCostService, LedgerFailureContext, PriceCatalogEntry
from app.providers.base import (
    ProviderCompletion,
    ProviderExecutionResult,
    ProviderResponseReference,
    ProviderUsage,
)
from app.settings import clear_settings_cache, get_settings


def _build_execution_result(
    *,
    provider: str,
    route: str,
    model: str,
    requested_model: str,
    generation_id: str,
    fallback_used: bool = False,
    primary_provider: str | None = None,
    fallback_reason: str | None = None,
    attempted_providers: tuple[str, ...] | None = None,
    usage: ProviderUsage | None = None,
) -> ProviderExecutionResult:
    normalized_usage = usage or ProviderUsage(
        input_tokens=1000,
        output_tokens=500,
        total_tokens=1500,
        latency_ms=24.5,
        upstream_request_id=f"upstream-{provider}",
        finish_reason="stop",
    )
    completion = ProviderCompletion(
        provider=provider,
        route=route,
        generation_id=generation_id,
        requested_model=requested_model,
        model=model,
        raw_completion='{"ok":true}',
        usage=normalized_usage,
        response_reference=ProviderResponseReference(
            response_id=f"resp-{provider}-{generation_id}",
            model_version=model,
            candidate_index=0,
        ),
        raw_response={"provider": provider},
    )

    return ProviderExecutionResult(
        completion=completion,
        primary_provider=primary_provider or provider,
        fallback_used=fallback_used,
        fallback_reason=fallback_reason,
        attempted_providers=attempted_providers or ((primary_provider or provider), provider),
    )


def test_cost_service_records_success_path_with_price_catalog_estimate(fake_database_state) -> None:
    service = AdapterCostService(get_settings())
    service.upsert_price_catalog_entry(
        PriceCatalogEntry(
            provider="gemini",
            model="gemini-2.0-flash",
            input_cost_per_unit_usd=Decimal("0.001"),
            output_cost_per_unit_usd=Decimal("0.002"),
        )
    )
    result = _build_execution_result(
        provider="gemini",
        route="interpret",
        model="gemini-2.0-flash",
        requested_model="llm-gateway",
        generation_id="gen-success-1",
    )

    ledger_entry = service.record_execution_result(
        request_id="req-success-1",
        request_type="media_prompt_interpretation",
        result=result,
    )

    assert ledger_entry.estimated_cost_usd == Decimal("0.00200000")
    stored_row = fake_database_state.ledger_rows["req-success-1"]
    assert stored_row["final_status"] == "success"
    assert stored_row["cache_status"] == "miss"
    assert stored_row["upstream_request_id"] == "upstream-gemini"
    assert stored_row["metadata"]["cost_source"] == "price_catalog"
    assert stored_row["metadata"]["estimated_cost_usd"] == "0.00200000"


def test_cost_service_records_failure_path_with_error_metadata(fake_database_state) -> None:
    service = AdapterCostService(get_settings())
    context = LedgerFailureContext(
        request_id="req-failure-1",
        generation_id="gen-failure-1",
        route="respond",
        request_type="media_delivery_response",
        provider="gemini",
        primary_provider="gemini",
        model="gemini-2.0-flash",
        requested_model="llm-gateway",
        error_class="ProviderRequestError",
        error_code="provider_timeout",
        metadata={"source": "unit-test"},
        usage=ProviderUsage(
            input_tokens=None,
            output_tokens=None,
            total_tokens=None,
            latency_ms=550.0,
            upstream_request_id="upstream-failure-1",
            finish_reason=None,
        ),
    )

    ledger_entry = service.record_failure(
        context,
        estimated_cost_usd=Decimal("0.015"),
    )

    assert ledger_entry.final_status == "failed"
    assert ledger_entry.error_code == "provider_timeout"
    stored_row = fake_database_state.ledger_rows["req-failure-1"]
    assert stored_row["error_class"] == "ProviderRequestError"
    assert stored_row["error_code"] == "provider_timeout"
    assert stored_row["upstream_request_id"] == "upstream-failure-1"
    assert stored_row["metadata"]["cost_source"] == "explicit"
    assert stored_row["metadata"]["source"] == "unit-test"


def test_cost_service_records_cache_hit_path_with_zero_cost(fake_database_state) -> None:
    service = AdapterCostService(get_settings())

    ledger_entry = service.record_cache_hit(
        request_id="req-cache-hit-1",
        generation_id="gen-cache-hit-1",
        route="interpret",
        request_type="media_prompt_interpretation",
        provider="gemini",
        model="gemini-2.0-flash",
        requested_model="llm-gateway",
        cache_key="a" * 64,
    )

    assert ledger_entry.cache_status == "hit"
    assert ledger_entry.estimated_cost_usd == Decimal("0")
    stored_row = fake_database_state.ledger_rows["req-cache-hit-1"]
    assert stored_row["cache_status"] == "hit"
    assert stored_row["estimated_cost_usd"] == Decimal("0")
    assert stored_row["metadata"]["cost_source"] == "cache_hit"


def test_cost_service_records_fallback_path_and_upstream_request_id(fake_database_state) -> None:
    service = AdapterCostService(get_settings())
    service.upsert_price_catalog_entry(
        PriceCatalogEntry(
            provider="openai",
            model="gpt-5.4",
            input_cost_per_unit_usd=Decimal("0.002"),
            output_cost_per_unit_usd=Decimal("0.004"),
        )
    )
    result = _build_execution_result(
        provider="openai",
        route="interpret",
        model="gpt-5.4",
        requested_model="llm-gateway",
        generation_id="gen-fallback-1",
        fallback_used=True,
        primary_provider="gemini",
        fallback_reason="provider_rate_limited",
        attempted_providers=("gemini", "openai"),
        usage=ProviderUsage(
            input_tokens=500,
            output_tokens=250,
            total_tokens=750,
            latency_ms=41.0,
            upstream_request_id="upstream-openai-1",
            finish_reason="completed",
        ),
    )

    ledger_entry = service.record_execution_result(
        request_id="req-fallback-1",
        request_type="media_prompt_interpretation",
        result=result,
    )

    assert ledger_entry.fallback_used is True
    assert ledger_entry.fallback_reason == "provider_rate_limited"
    stored_row = fake_database_state.ledger_rows["req-fallback-1"]
    assert stored_row["primary_provider"] == "gemini"
    assert stored_row["provider"] == "openai"
    assert stored_row["attempted_providers"] == ["gemini", "openai"]
    assert stored_row["upstream_request_id"] == "upstream-openai-1"


def test_cost_service_uses_route_default_estimate_when_price_catalog_is_missing(fake_database_state) -> None:
    service = AdapterCostService(get_settings())
    result = _build_execution_result(
        provider="gemini",
        route="interpret",
        model="gemini-2.0-flash",
        requested_model="llm-gateway",
        generation_id="gen-default-estimate-1",
    )

    ledger_entry = service.record_execution_result(
        request_id="req-default-estimate-1",
        request_type="media_prompt_interpretation",
        result=result,
    )

    assert ledger_entry.estimated_cost_usd == Decimal("0.025")
    stored_row = fake_database_state.ledger_rows["req-default-estimate-1"]
    assert stored_row["metadata"]["cost_source"] == "route_default"
    assert stored_row["metadata"]["estimated_cost_usd"] == "0.02500000"