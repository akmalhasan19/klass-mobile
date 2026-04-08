from __future__ import annotations

import asyncio
from dataclasses import dataclass

from app.errors import ProviderConfigurationError, ProviderRequestError
from app.models import InterpretationRequest
from app.providers.base import ProviderCompletion, ProviderResponseReference, ProviderUsage
from app.providers.routing import ProviderRouter
from app.settings import clear_settings_cache, get_settings


def interpretation_payload() -> dict[str, object]:
    return {
        "request_type": "media_prompt_interpretation",
        "generation_id": "gen-route-1",
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "teacher_prompt": "Buatkan ringkasan gaya untuk kelas 4.",
            "preferred_output_type": "pdf",
            "subject_context": {
                "id": 1,
                "name": "IPA",
                "slug": "ipa",
            },
            "sub_subject_context": {
                "id": 2,
                "name": "Gaya",
                "slug": "gaya",
            },
        },
    }


@dataclass
class StubClient:
    name: str
    completion_text: str
    should_fail: bool = False
    failure_code: str = "provider_rate_limited"
    calls: list[str] | None = None

    def __post_init__(self) -> None:
        if self.calls is None:
            self.calls = []

    def normalize_interpretation_request(self, payload: InterpretationRequest):
        self.calls.append(f"normalize:{self.name}:{payload.generation_id}")
        return type(
            "RequestStub",
            (),
            {
                "route": "interpret",
                "request_type": payload.request_type,
                "generation_id": payload.generation_id,
                "requested_model": payload.model,
                "model": f"{self.name}-model",
                "instruction": payload.instruction,
                "input_payload": payload.input.model_dump(mode="python"),
            },
        )()

    async def complete(self, request):
        self.calls.append(f"complete:{self.name}:{request.generation_id}")
        if self.should_fail:
            raise ProviderRequestError(
                code=self.failure_code,
                message="simulated provider failure",
                status_code=429,
                details={"provider": self.name},
                retryable=True,
            )

        return ProviderCompletion(
            provider=self.name,
            route="interpret",
            generation_id=request.generation_id,
            requested_model=request.requested_model,
            model=request.model,
            raw_completion=self.completion_text,
            usage=ProviderUsage(
                input_tokens=10,
                output_tokens=5,
                total_tokens=15,
                latency_ms=12.3,
                upstream_request_id=f"req-{self.name}",
                finish_reason="stop",
            ),
            response_reference=ProviderResponseReference(
                response_id=f"resp-{self.name}",
                model_version=request.model,
                candidate_index=0,
            ),
            raw_response={"provider": self.name},
        )


class StubRegistry:
    def __init__(self, clients):
        self.clients = clients

    def build_client(self, provider_name, settings):
        return self.clients[provider_name]


def test_provider_router_allows_different_providers_per_route_via_active_config(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER", "gemini")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER", "openai")
    monkeypatch.setenv("LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE", "true")
    clear_settings_cache()
    router = ProviderRouter(get_settings())

    interpret_policy = router.policy_for_route("interpret")
    delivery_policy = router.policy_for_route("respond")

    assert interpret_policy.primary_provider == "gemini"
    assert delivery_policy.primary_provider == "openai"
    assert interpret_policy.allow_route_divergence is True
    assert delivery_policy.allow_route_divergence is True


def test_provider_router_rejects_divergent_route_providers_when_disabled(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER", "gemini")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER", "openai")
    monkeypatch.setenv("LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE", "false")
    clear_settings_cache()
    router = ProviderRouter(get_settings())

    try:
        router.policy_for_route("interpret")
    except ProviderConfigurationError as exc:
        assert exc.code == "provider_route_divergence_disallowed"
        assert exc.status_code == 503
    else:
        raise AssertionError("Expected ProviderConfigurationError to be raised.")


def test_provider_router_uses_fallback_provider_when_primary_is_rate_limited(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER", "gemini")
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER", "openai")
    monkeypatch.setenv("LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES", "provider_rate_limited,provider_unavailable")
    clear_settings_cache()
    primary_client = StubClient(name="gemini", completion_text="", should_fail=True)
    fallback_client = StubClient(name="openai", completion_text='{"schema_version":"media_prompt_understanding.v1"}')
    router = ProviderRouter(
        get_settings(),
        registry=StubRegistry({
            "gemini": primary_client,
            "openai": fallback_client,
        }),
    )
    payload = InterpretationRequest.model_validate(interpretation_payload())

    result = asyncio.run(router.execute_interpretation(payload))

    assert result.primary_provider == "gemini"
    assert result.fallback_used is True
    assert result.fallback_reason == "provider_rate_limited"
    assert result.attempted_providers == ("gemini", "openai")
    assert result.completion.provider == "openai"
    assert primary_client.calls == ["normalize:gemini:gen-route-1", "complete:gemini:gen-route-1"]
    assert fallback_client.calls == ["normalize:openai:gen-route-1", "complete:openai:gen-route-1"]


def test_provider_router_does_not_fallback_for_non_policy_error_code(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER", "gemini")
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER", "openai")
    monkeypatch.setenv("LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES", "provider_rate_limited")
    clear_settings_cache()
    primary_client = StubClient(
        name="gemini",
        completion_text="",
        should_fail=True,
        failure_code="provider_request_invalid",
    )
    fallback_client = StubClient(name="openai", completion_text='{"schema_version":"media_prompt_understanding.v1"}')
    router = ProviderRouter(
        get_settings(),
        registry=StubRegistry({
            "gemini": primary_client,
            "openai": fallback_client,
        }),
    )
    payload = InterpretationRequest.model_validate(interpretation_payload())

    try:
        asyncio.run(router.execute_interpretation(payload))
    except ProviderRequestError as exc:
        assert exc.code == "provider_request_invalid"
        assert fallback_client.calls == []
    else:
        raise AssertionError("Expected ProviderRequestError to be raised.")