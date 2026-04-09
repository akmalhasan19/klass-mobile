from __future__ import annotations

from decimal import Decimal

from app.governance import AdapterGovernanceService
from app.providers.base import ProviderUsage
from app.settings import clear_settings_cache, get_settings


def test_interpretation_preflight_denies_after_minute_quota_is_consumed(
    monkeypatch,
    fake_database_state,
) -> None:
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_MINUTE", "1")
    clear_settings_cache()
    service = AdapterGovernanceService(get_settings())

    allowed = service.preflight_check(
        route="interpret",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-1",
        generation_id="gen-1",
    )
    assert allowed.allowed is True

    service.record_usage(
        route="interpret",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-1",
        generation_id="gen-1",
        usage=ProviderUsage(
            input_tokens=100,
            output_tokens=50,
            total_tokens=150,
            latency_ms=12.5,
            upstream_request_id="upstream-1",
            finish_reason="stop",
        ),
        estimated_cost_usd=Decimal("0.025"),
    )

    denied = service.preflight_check(
        route="interpret",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-2",
        generation_id="gen-1",
    )

    assert denied.allowed is False
    assert denied.action == "deny"
    assert denied.code == "route_rate_limited"
    assert denied.details["metric"] == "requests"
    assert denied.details["current_value"] == 1
    assert denied.details["projected_value"] == 2

    minute_policy = next(
        row
        for row in fake_database_state.policies.values()
        if row["route"] == "interpret" and row["window_unit"] == "minute"
    )
    minute_bucket = next(
        row
        for row in fake_database_state.buckets.values()
        if row["policy_id"] == minute_policy["id"]
    )
    assert minute_bucket["request_count"] == 1
    assert minute_bucket["deny_count"] == 1


def test_delivery_route_can_be_disabled_without_breaking_fallback(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_ROUTE_ENABLED", "false")
    clear_settings_cache()
    service = AdapterGovernanceService(get_settings())

    decision = service.preflight_check(
        route="respond",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-delivery-disabled",
        generation_id="gen-delivery-disabled",
    )

    assert decision.allowed is False
    assert decision.action == "degrade"
    assert decision.code == "delivery_route_disabled"
    assert decision.details["fallback_allowed"] is True
    assert decision.details["reason"] == "route_disabled"


def test_delivery_daily_budget_can_trigger_degrade_mode(monkeypatch, fake_database_state) -> None:
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD", "0.005")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD", "0.010")
    clear_settings_cache()
    service = AdapterGovernanceService(get_settings())

    decision = service.preflight_check(
        route="respond",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-budget-1",
        generation_id="gen-budget-1",
    )

    assert decision.allowed is False
    assert decision.action == "degrade"
    assert decision.code == "route_budget_exhausted"
    assert decision.details["metric"] == "estimated_cost_usd"
    assert decision.details["fallback_allowed"] is True

    day_policy = next(
        row
        for row in fake_database_state.policies.values()
        if row["route"] == "respond" and row["window_unit"] == "day"
    )
    day_bucket = next(
        row
        for row in fake_database_state.buckets.values()
        if row["policy_id"] == day_policy["id"]
    )
    assert day_bucket["request_count"] == 0
    assert day_bucket["deny_count"] == 1


def test_budget_status_reports_warning_before_exhaustion(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD", "0.020")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD", "0.010")
    clear_settings_cache()
    service = AdapterGovernanceService(get_settings())

    service.record_usage(
        route="respond",
        provider="gemini",
        model="gemini-2.0-flash",
        request_id="req-warning-1",
        generation_id="gen-warning-1",
        usage=ProviderUsage(
            input_tokens=25,
            output_tokens=10,
            total_tokens=35,
            latency_ms=8.0,
            upstream_request_id="upstream-warning-1",
            finish_reason="stop",
        ),
        estimated_cost_usd=Decimal("0.018"),
    )

    statuses = {
        status.route: status
        for status in service.budget_statuses()
    }
    delivery_status = statuses["respond"]

    assert delivery_status.budget_status == "warning"
    assert delivery_status.exhausted_action == "degrade"
    assert delivery_status.remaining_budget_usd == Decimal("0.002")
    assert delivery_status.next_request_would_exhaust_budget is True