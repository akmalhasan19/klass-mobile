from __future__ import annotations

from decimal import Decimal

from app.costs import AdapterCostService, LedgerFailureContext, PriceCatalogEntry
from app.governance import AdapterGovernanceService
from app.providers.base import (
    ProviderCompletion,
    ProviderExecutionResult,
    ProviderResponseReference,
    ProviderUsage,
)
from app.settings import get_settings


def _execution_result(
    *,
    route: str,
    provider: str,
    model: str,
    generation_id: str,
    request_id_suffix: str,
    latency_ms: float,
    input_tokens: int,
    output_tokens: int,
) -> ProviderExecutionResult:
    usage = ProviderUsage(
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        total_tokens=input_tokens + output_tokens,
        latency_ms=latency_ms,
        upstream_request_id=f"upstream-{request_id_suffix}",
        finish_reason="stop",
    )
    completion = ProviderCompletion(
        provider=provider,
        route=route,
        generation_id=generation_id,
        requested_model="llm-gateway",
        model=model,
        raw_completion='{"ok":true}',
        usage=usage,
        response_reference=ProviderResponseReference(
            response_id=f"resp-{request_id_suffix}",
            model_version=model,
            candidate_index=0,
        ),
        raw_response={"provider": provider},
    )

    return ProviderExecutionResult(
        completion=completion,
        primary_provider=provider,
        fallback_used=False,
        fallback_reason=None,
        attempted_providers=(provider,),
    )


def test_ops_summary_endpoint_returns_metrics_and_active_providers(client) -> None:
    settings = get_settings()
    cost_service = AdapterCostService(settings)
    governance_service = AdapterGovernanceService(settings)
    cost_service.upsert_price_catalog_entry(
        PriceCatalogEntry(
            provider="gemini",
            model="gemini-2.0-flash",
            input_cost_per_unit_usd=Decimal("0.001"),
            output_cost_per_unit_usd=Decimal("0.002"),
        )
    )
    cost_service.record_execution_result(
        request_id="req-ops-success-1",
        request_type="media_prompt_interpretation",
        result=_execution_result(
            route="interpret",
            provider="gemini",
            model="gemini-2.0-flash",
            generation_id="gen-ops-1",
            request_id_suffix="ops-success-1",
            latency_ms=20.0,
            input_tokens=1000,
            output_tokens=500,
        ),
    )
    cost_service.record_cache_hit(
        request_id="req-ops-cache-1",
        generation_id="gen-ops-1",
        route="interpret",
        request_type="media_prompt_interpretation",
        provider="gemini",
        model="gemini-2.0-flash",
        requested_model="llm-gateway",
        cache_key="b" * 64,
    )
    cost_service.record_failure(
        LedgerFailureContext(
            request_id="req-ops-failure-1",
            generation_id="gen-ops-2",
            route="respond",
            request_type="media_delivery_response",
            provider="gemini",
            primary_provider="gemini",
            model="gemini-2.0-flash",
            requested_model="llm-gateway",
            error_class="ProviderRequestError",
            error_code="provider_timeout",
            usage=ProviderUsage(
                input_tokens=None,
                output_tokens=None,
                total_tokens=None,
                latency_ms=40.0,
                upstream_request_id="upstream-ops-failure-1",
                finish_reason=None,
            ),
        ),
        estimated_cost_usd=Decimal("0.010"),
    )

    policies = governance_service.sync_default_policies()
    interpretation_day_policy = next(
        policy
        for policy in policies
        if policy.record.scope_type == "route"
        and policy.record.route == "interpret"
        and policy.record.window_unit == "day"
    )
    governance_service.record_denial(
        route="interpret",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-ops-deny-1",
        generation_id="gen-ops-1",
        policy=interpretation_day_policy,
    )

    response = client.get("/v1/ops/summary?days=1")

    assert response.status_code == 200
    payload = response.json()
    assert payload["schema_version"] == "llm_adapter_ops.v1"
    assert payload["active_routes"][0]["route"] == "interpret"
    assert payload["active_routes"][0]["provider"] == "gemini"
    assert payload["active_routes"][1]["route"] == "respond"

    interpret_route = next(route for route in payload["routes"] if route["route"] == "interpret")
    assert interpret_route["request_count"] == 2
    assert interpret_route["cache_hit_ratio"] == 0.5
    assert interpret_route["deny_count"] == 1
    assert interpret_route["deny_rate"] == 0.333333
    assert interpret_route["average_latency_ms"] == 20.0
    assert interpret_route["total_estimated_cost_usd"] == "0.00200000"

    respond_route = next(route for route in payload["routes"] if route["route"] == "respond")
    assert respond_route["request_count"] == 1
    assert respond_route["error_count"] == 1
    assert respond_route["total_estimated_cost_usd"] == "0.01000000"

    provider_metric = next(metric for metric in payload["provider_models"] if metric["route"] == "interpret")
    assert provider_metric["provider"] == "gemini"
    assert provider_metric["model"] == "gemini-2.0-flash"
    assert provider_metric["request_count"] == 2
    assert provider_metric["cache_hit_ratio"] == 0.5