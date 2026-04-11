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
        "generation_id": "gen-123",
        "model": "gpt-5.4",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "teacher_prompt": "Buatkan handout pecahan untuk kelas 5.",
            "preferred_output_type": "pdf",
            "subject_context": {
                "id": 10,
                "name": "Matematika",
                "slug": "matematika",
            },
            "sub_subject_context": {
                "id": 11,
                "name": "Pecahan",
                "slug": "pecahan",
            },
        },
    }


def delivery_payload() -> dict[str, object]:
    return {
        "request_type": "media_delivery_response",
        "generation_id": "gen-456",
        "model": "gpt-5.4",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "artifact": {
                "output_type": "pdf",
                "title": "Handout Pecahan Kelas 5",
                "file_url": "https://example.com/materials/handout-pecahan-kelas-5.pdf",
                "thumbnail_url": "https://example.com/gallery/handout-pecahan-kelas-5.svg",
                "mime_type": "application/pdf",
                "filename": "handout-pecahan-kelas-5.pdf",
            },
            "publication": {
                "topic": {
                    "id": "topic-123",
                    "title": "Handout Pecahan Kelas 5",
                },
                "content": {
                    "id": "content-123",
                    "title": "Handout Pecahan Kelas 5",
                    "type": "brief",
                    "media_url": "https://example.com/materials/handout-pecahan-kelas-5.pdf",
                },
                "recommended_project": {
                    "id": "project-123",
                    "title": "Handout Pecahan Kelas 5",
                    "project_file_url": "https://example.com/materials/handout-pecahan-kelas-5.pdf",
                },
            },
            "preview_summary": "Handout siap dipakai untuk penguatan konsep dan latihan singkat.",
            "teacher_delivery_summary": "Bagikan file setelah pengantar singkat.",
            "generation_summary": "Handout untuk penguatan konsep pecahan.",
        },
    }


def test_gemini_provider_normalizes_interpretation_request_to_vendor_neutral_shape(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_INTERPRET_MODEL", "gemini-1.5-flash")
    clear_settings_cache()
    settings = get_settings()
    provider = ProviderRegistry().build_client("gemini", settings)
    request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )

    assert request.route == "interpret"
    assert request.request_type == "media_prompt_interpretation"
    assert request.generation_id == "gen-123"
    assert request.requested_model == "gpt-5.4"
    assert request.model == "gemini-1.5-flash"
    assert request.input_payload["teacher_prompt"] == "Buatkan handout pecahan untuk kelas 5."
    assert json.loads(request.serialize_prompt_payload()) == {
        "generation_id": "gen-123",
        "input": request.input_payload,
        "request_type": "media_prompt_interpretation",
        "route": "interpret",
    }


def test_gemini_provider_normalizes_delivery_request_to_vendor_neutral_shape(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_DELIVERY_MODEL", "gemini-1.5-pro")
    clear_settings_cache()
    settings = get_settings()
    provider = ProviderRegistry().build_client("gemini", settings)
    request = provider.normalize_delivery_request(DeliveryRequest.model_validate(delivery_payload()))

    assert request.route == "respond"
    assert request.request_type == "media_delivery_response"
    assert request.generation_id == "gen-456"
    assert request.requested_model == "gpt-5.4"
    assert request.model == "gemini-1.5-pro"
    assert request.input_payload["artifact"]["output_type"] == "pdf"
    assert request.input_payload["publication"]["recommended_project"]["id"] == "project-123"


def test_gemini_provider_maps_request_response_usage_and_reference_metadata() -> None:
    settings = get_settings()
    provider = ProviderRegistry().build_client("gemini", settings)
    request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )

    def handler(http_request: httpx.Request) -> httpx.Response:
        assert str(http_request.url) == (
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
            "?key=test-gemini-api-key"
        )
        payload = json.loads(http_request.content.decode("utf-8"))
        system_instruction = payload["systemInstruction"]["parts"][0]["text"]
        assert system_instruction.startswith("Return exactly one JSON object.")
        assert "Adapter contract guardrails:" in system_instruction
        assert json.loads(payload["contents"][0]["parts"][0]["text"]) == {
            "generation_id": "gen-123",
            "input": request.input_payload,
            "request_type": "media_prompt_interpretation",
            "route": "interpret",
        }
        assert payload["generationConfig"]["responseMimeType"] == "application/json"

        return httpx.Response(
            status_code=200,
            headers={"x-goog-request-id": "goog-req-123"},
            json={
                "responseId": "gemini-response-123",
                "modelVersion": "gemini-2.0-flash-001",
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {
                            "parts": [
                                {"text": "{\"schema_version\":"},
                                {"text": "\"media_prompt_understanding.v1\"}"},
                            ]
                        },
                    }
                ],
                "usageMetadata": {
                    "promptTokenCount": 123,
                    "candidatesTokenCount": 45,
                    "totalTokenCount": 168,
                },
            },
        )

    async def run_completion() -> object:
        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as client:
            return await provider.complete(request, http_client=client)

    completion = asyncio.run(run_completion())

    assert completion.provider == "gemini"
    assert completion.route == "interpret"
    assert completion.model == "gemini-2.0-flash"
    assert completion.raw_completion == '{"schema_version":"media_prompt_understanding.v1"}'
    assert completion.usage.input_tokens == 123
    assert completion.usage.output_tokens == 45
    assert completion.usage.total_tokens == 168
    assert completion.usage.finish_reason == "stop"
    assert completion.usage.upstream_request_id == "goog-req-123"
    assert completion.usage.latency_ms is not None
    assert completion.response_reference.response_id == "gemini-response-123"
    assert completion.response_reference.model_version == "gemini-2.0-flash-001"
    assert completion.response_reference.candidate_index == 0


def test_gemini_provider_maps_rate_limit_errors_to_stable_adapter_error() -> None:
    settings = get_settings()
    provider = ProviderRegistry().build_client("gemini", settings)
    request = provider.normalize_interpretation_request(
        InterpretationRequest.model_validate(interpretation_payload())
    )

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            status_code=429,
            headers={"x-goog-request-id": "goog-rl-1"},
            json={
                "error": {
                    "code": 429,
                    "message": "Rate limit exceeded.",
                    "status": "RESOURCE_EXHAUSTED",
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
        assert exc.details["upstream_request_id"] == "goog-rl-1"
        assert exc.details["provider_status"] == "RESOURCE_EXHAUSTED"
    else:
        raise AssertionError("Expected ProviderRequestError to be raised.")


def test_provider_registry_builds_openai_provider_when_configured(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    clear_settings_cache()
    settings = get_settings()

    provider = ProviderRegistry().build_client("openai", settings)

    assert provider.name == "openai"