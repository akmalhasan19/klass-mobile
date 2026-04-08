from __future__ import annotations

import asyncio
import json

import httpx

from app.errors import ProviderRequestError
from app.models import DeliveryRequest, InterpretationRequest
from app.providers.registry import ProviderRegistry
from app.settings import clear_settings_cache, get_settings


def interpretation_payload() -> dict[str, object]:
    return {
        "request_type": "media_prompt_interpretation",
        "generation_id": "gen-789",
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "teacher_prompt": "Buatkan outline materi gaya untuk kelas 4.",
            "preferred_output_type": "pdf",
            "subject_context": {
                "id": 10,
                "name": "IPA",
                "slug": "ipa",
            },
            "sub_subject_context": {
                "id": 11,
                "name": "Gaya",
                "slug": "gaya",
            },
        },
    }


def delivery_payload() -> dict[str, object]:
    return {
        "request_type": "media_delivery_response",
        "generation_id": "gen-790",
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "artifact": {
                "output_type": "pdf",
                "title": "Handout Gaya Kelas 4",
                "file_url": "https://example.com/materials/handout-gaya-kelas-4.pdf",
                "thumbnail_url": "https://example.com/gallery/handout-gaya-kelas-4.svg",
                "mime_type": "application/pdf",
                "filename": "handout-gaya-kelas-4.pdf",
            },
            "publication": {
                "topic": {
                    "id": "topic-789",
                    "title": "Handout Gaya Kelas 4",
                },
                "content": None,
                "recommended_project": None,
            },
            "preview_summary": "Handout siap dipakai untuk pengantar materi gaya.",
            "teacher_delivery_summary": "Bagikan setelah demonstrasi sederhana.",
            "generation_summary": "Handout pengantar konsep gaya untuk siswa sekolah dasar.",
        },
    }


def test_openai_provider_uses_route_specific_default_model_when_request_model_is_provider_neutral(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_INTERPRET_MODEL", "gpt-5.4-mini")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_DELIVERY_MODEL", "gpt-5.4")
    clear_settings_cache()
    settings = get_settings()
    provider = ProviderRegistry().build_client("openai", settings)

    interpretation_request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )
    delivery_request = provider.normalize_delivery_request(
        DeliveryRequest.model_validate(delivery_payload())
    )

    assert interpretation_request.model == "gpt-5.4-mini"
    assert interpretation_request.requested_model == "llm-gateway"
    assert delivery_request.model == "gpt-5.4"
    assert delivery_request.route == "respond"


def test_openai_provider_maps_responses_api_payload_to_normalized_completion(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_ORGANIZATION", "org-123")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_PROJECT", "proj-123")
    clear_settings_cache()
    settings = get_settings()
    provider = ProviderRegistry().build_client("openai", settings)
    request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )

    def handler(http_request: httpx.Request) -> httpx.Response:
        assert str(http_request.url) == "https://api.openai.com/v1/responses"
        assert http_request.headers["authorization"] == "Bearer test-openai-key"
        assert http_request.headers["openai-organization"] == "org-123"
        assert http_request.headers["openai-project"] == "proj-123"
        payload = json.loads(http_request.content.decode("utf-8"))
        assert payload["model"] == request.model
        assert payload["text"]["format"]["type"] == "json_object"
        assert payload["input"][0]["role"] == "system"
        assert payload["input"][1]["role"] == "user"
        assert json.loads(payload["input"][1]["content"][0]["text"]) == {
            "generation_id": "gen-789",
            "input": request.input_payload,
            "request_type": "media_prompt_interpretation",
            "route": "interpret",
        }

        return httpx.Response(
            status_code=200,
            headers={"x-request-id": "openai-req-123"},
            json={
                "id": "resp_123",
                "model": "gpt-5.4",
                "status": "completed",
                "output": [
                    {
                        "type": "message",
                        "content": [
                            {
                                "type": "output_text",
                                "text": '{"schema_version":"media_prompt_understanding.v1"}',
                            }
                        ],
                    }
                ],
                "usage": {
                    "input_tokens": 140,
                    "output_tokens": 52,
                    "total_tokens": 192,
                },
            },
        )

    async def run_completion() -> object:
        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as client:
            return await provider.complete(request, http_client=client)

    completion = asyncio.run(run_completion())

    assert completion.provider == "openai"
    assert completion.route == "interpret"
    assert completion.requested_model == "llm-gateway"
    assert completion.model == "gpt-5.4"
    assert completion.raw_completion == '{"schema_version":"media_prompt_understanding.v1"}'
    assert completion.usage.input_tokens == 140
    assert completion.usage.output_tokens == 52
    assert completion.usage.total_tokens == 192
    assert completion.usage.finish_reason == "completed"
    assert completion.usage.upstream_request_id == "openai-req-123"
    assert completion.response_reference.response_id == "resp_123"
    assert completion.response_reference.model_version == "gpt-5.4"


def test_openai_provider_maps_chat_completion_shape_for_readiness_of_future_switch(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_INTERPRET_MODEL", "gpt-5.4")
    clear_settings_cache()
    settings = get_settings()
    provider = ProviderRegistry().build_client("openai", settings)
    request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            status_code=200,
            json={
                "id": "chatcmpl-123",
                "model": "gpt-5.4",
                "choices": [
                    {
                        "finish_reason": "stop",
                        "message": {
                            "content": '{"schema_version":"media_prompt_understanding.v1"}',
                        },
                    }
                ],
                "usage": {
                    "prompt_tokens": 121,
                    "completion_tokens": 33,
                    "total_tokens": 154,
                },
            },
        )

    async def run_completion() -> object:
        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as client:
            return await provider.complete(request, http_client=client)

    completion = asyncio.run(run_completion())

    assert completion.raw_completion == '{"schema_version":"media_prompt_understanding.v1"}'
    assert completion.usage.input_tokens == 121
    assert completion.usage.output_tokens == 33
    assert completion.usage.total_tokens == 154
    assert completion.usage.finish_reason == "stop"


def test_openai_provider_maps_rate_limit_errors_to_stable_adapter_error(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    clear_settings_cache()
    settings = get_settings()
    provider = ProviderRegistry().build_client("openai", settings)
    request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            status_code=429,
            headers={"x-request-id": "openai-rl-1"},
            json={
                "error": {
                    "type": "rate_limit_error",
                    "message": "Too many requests.",
                    "code": "rate_limit_exceeded",
                }
            },
        )

    async def run_completion() -> None:
        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as client:
            await provider.complete(request, http_client=client)

    try:
        asyncio.run(run_completion())
    except ProviderRequestError as exc:
        assert exc.code == "provider_rate_limited"
        assert exc.status_code == 429
        assert exc.retryable is True
        assert exc.details["upstream_request_id"] == "openai-rl-1"
        assert exc.details["provider_type"] == "rate_limit_error"
        assert exc.details["provider_code"] == "rate_limit_exceeded"
    else:
        raise AssertionError("Expected ProviderRequestError to be raised.")