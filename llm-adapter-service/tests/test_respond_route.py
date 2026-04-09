from __future__ import annotations

import hashlib
import hmac
import json
import time

from app.cache import DELIVERY_CACHE_TABLE_NAME
from app.errors import ProviderRequestError
from app.providers.base import (
    ProviderCompletion,
    ProviderExecutionResult,
    ProviderResponseReference,
    ProviderUsage,
)
from app.settings import clear_settings_cache


def build_signed_request(
    payload: dict[str, object],
    *,
    generation_id: str,
    request_id: str,
    secret: str = "test-shared-secret",
) -> tuple[bytes, dict[str, str]]:
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    issued_at = str(int(time.time()))
    signature = hmac.new(
        secret.encode("utf-8"),
        issued_at.encode("utf-8") + b"." + body,
        hashlib.sha256,
    ).hexdigest()

    return body, {
        "Content-Type": "application/json",
        "X-Request-Id": request_id,
        "X-Klass-Generation-Id": generation_id,
        "X-Klass-Request-Timestamp": issued_at,
        "X-Klass-Signature-Algorithm": "hmac-sha256",
        "X-Klass-Signature": signature,
    }


def delivery_request_payload(
    *,
    generation_id: str = "gen-respond-1",
    request_type: str = "media_delivery_response",
    preview_summary: str = "Media siap digunakan untuk penguatan konsep dan latihan singkat.",
) -> dict[str, object]:
    return {
        "request_type": request_type,
        "generation_id": generation_id,
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "artifact": {
                "output_type": "docx",
                "title": "Handout Aljabar Kelas 8",
                "file_url": "https://example.com/materials/handout-aljabar-kelas-8.docx",
                "thumbnail_url": "https://example.com/thumb.png",
                "mime_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "filename": "handout-aljabar-kelas-8.docx",
            },
            "publication": {
                "topic": {
                    "id": "topic-200",
                    "title": "Handout Aljabar Kelas 8",
                },
                "content": {
                    "id": "content-200",
                    "title": "Handout Aljabar Kelas 8",
                    "type": "brief",
                    "media_url": "https://example.com/materials/handout-aljabar-kelas-8.docx",
                },
                "recommended_project": {
                    "id": "project-200",
                    "title": "Handout Aljabar Kelas 8",
                    "project_file_url": "https://example.com/materials/handout-aljabar-kelas-8.docx",
                },
            },
            "preview_summary": preview_summary,
            "teacher_delivery_summary": "Gunakan handout ini untuk pengantar lalu lanjutkan ke latihan contoh soal.",
            "generation_summary": "Handout editable untuk penguatan konsep aljabar dasar.",
        },
    }


def valid_delivery_response_payload() -> dict[str, object]:
    return {
        "schema_version": "media_delivery_response.v1",
        "title": "Handout Aljabar Kelas 8 siap digunakan",
        "preview_summary": "Handout ini cocok untuk penguatan konsep dan latihan singkat di kelas 8.",
        "teacher_message": "Materi sudah siap digunakan. Tinjau contoh soal sebelum dibagikan ke siswa.",
        "artifact": {
            "output_type": "docx",
            "title": "Handout Aljabar Kelas 8",
            "file_url": "https://example.com/materials/handout-aljabar-kelas-8.docx",
            "thumbnail_url": "https://example.com/thumb.png",
            "mime_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "filename": "handout-aljabar-kelas-8.docx",
        },
        "publication": {
            "topic": {
                "id": "topic-200",
                "title": "Handout Aljabar Kelas 8",
            },
            "content": {
                "id": "content-200",
                "title": "Handout Aljabar Kelas 8",
                "type": "brief",
                "media_url": "https://example.com/materials/handout-aljabar-kelas-8.docx",
            },
            "recommended_project": {
                "id": "project-200",
                "title": "Handout Aljabar Kelas 8",
                "project_file_url": "https://example.com/materials/handout-aljabar-kelas-8.docx",
            },
        },
    }


def build_execution_result(
    *,
    generation_id: str,
    raw_completion: str,
    provider: str = "gemini",
    model: str = "gemini-2.0-flash",
    requested_model: str = "llm-gateway",
    primary_provider: str | None = None,
    fallback_used: bool = False,
    fallback_reason: str | None = None,
    attempted_providers: tuple[str, ...] | None = None,
) -> ProviderExecutionResult:
    return ProviderExecutionResult(
        completion=ProviderCompletion(
            provider=provider,
            route="respond",
            generation_id=generation_id,
            requested_model=requested_model,
            model=model,
            raw_completion=raw_completion,
            usage=ProviderUsage(
                input_tokens=800,
                output_tokens=350,
                total_tokens=1150,
                latency_ms=19.2,
                upstream_request_id=f"upstream-{provider}-{generation_id}",
                finish_reason="stop",
            ),
            response_reference=ProviderResponseReference(
                response_id=f"resp-{provider}-{generation_id}",
                model_version=model,
                candidate_index=0,
            ),
            raw_response={"provider": provider},
        ),
        primary_provider=primary_provider or provider,
        fallback_used=fallback_used,
        fallback_reason=fallback_reason,
        attempted_providers=attempted_providers or (primary_provider or provider, provider),
    )


def test_respond_route_returns_validated_payload_and_records_cache_and_ledger(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_delivery_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setattr("app.delivery.ProviderRouter.execute_delivery", stub_execute)
    request_payload = delivery_request_payload(generation_id="gen-respond-success-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-success-1",
        request_id="req-respond-success-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["schema_version"] == "media_delivery_response.v1"
    assert payload["response_meta"]["llm_used"] is True
    assert payload["response_meta"]["provider"] == "gemini"
    assert payload["response_meta"]["model"] == "gemini-2.0-flash"
    assert payload["fallback"]["triggered"] is False
    assert payload["recommended_next_steps"] == []
    assert payload["classroom_tips"] == []
    assert response.headers["X-Klass-LLM-Provider"] == "gemini"
    assert response.headers["X-Klass-LLM-Model"] == "gemini-2.0-flash"
    assert response.headers["X-Klass-LLM-Primary-Provider"] == "gemini"
    assert response.headers["X-Klass-LLM-Fallback-Used"] == "false"
    assert calls == ["gen-respond-success-1"]
    assert len(fake_database_state.cache_tables[DELIVERY_CACHE_TABLE_NAME]) == 1
    ledger_row = fake_database_state.ledger_rows["req-respond-success-1"]
    assert ledger_row["final_status"] == "success"
    assert ledger_row["cache_status"] == "miss"
    assert ledger_row["error_code"] is None


def test_respond_route_reuses_cache_across_generations_with_same_semantic_request(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_delivery_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setattr("app.delivery.ProviderRouter.execute_delivery", stub_execute)

    first_payload = delivery_request_payload(generation_id="gen-respond-cache-1")
    first_body, first_headers = build_signed_request(
        first_payload,
        generation_id="gen-respond-cache-1",
        request_id="req-respond-cache-1",
    )
    first_response = client.post("/v1/respond", content=first_body, headers=first_headers)

    second_payload = delivery_request_payload(generation_id="gen-respond-cache-2")
    second_body, second_headers = build_signed_request(
        second_payload,
        generation_id="gen-respond-cache-2",
        request_id="req-respond-cache-2",
    )
    second_response = client.post("/v1/respond", content=second_body, headers=second_headers)

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert second_response.headers["X-Klass-LLM-Provider"] == "gemini"
    assert second_response.headers["X-Klass-LLM-Model"] == "gemini-2.0-flash"
    assert second_response.headers["X-Klass-LLM-Primary-Provider"] == "gemini"
    assert calls == ["gen-respond-cache-1"]
    second_ledger_row = fake_database_state.ledger_rows["req-respond-cache-2"]
    assert second_ledger_row["cache_status"] == "hit"
    assert second_ledger_row["final_status"] == "success"


def test_respond_route_rejects_invalid_request_type(client) -> None:
    request_payload = delivery_request_payload(
        generation_id="gen-respond-invalid-type-1",
        request_type="media_prompt_interpretation",
    )
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-invalid-type-1",
        request_id="req-respond-invalid-type-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["code"] == "delivery_request_type_invalid"


def test_respond_route_rejects_missing_preview_summary_early(client, fake_database_state) -> None:
    request_payload = delivery_request_payload(
        generation_id="gen-respond-no-preview-1",
        preview_summary="",
    )
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-no-preview-1",
        request_id="req-respond-no-preview-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["code"] == "preview_summary_missing"
    assert fake_database_state.ledger_rows == {}


def test_respond_route_rejects_raw_binary_fields_from_request_contract(client, fake_database_state) -> None:
    request_payload = delivery_request_payload(generation_id="gen-respond-binary-1")
    request_payload["input"]["artifact"]["binary_base64"] = "ZmFrZS1iaW5hcnktYnl0ZXM="
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-binary-1",
        request_id="req-respond-binary-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 422
    payload = response.json()
    assert payload["code"] == "delivery_request_invalid"
    assert any(error["loc"][-1] == "binary_base64" for error in payload["details"]["errors"])
    assert fake_database_state.ledger_rows == {}


def test_respond_route_returns_structured_failure_when_provider_payload_is_invalid(client, fake_database_state, monkeypatch) -> None:
    raw_completion = '{"schema_version":"media_delivery_response.v1","title":"partial only"}'

    async def stub_execute(self, payload):
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=raw_completion,
        )

    monkeypatch.setattr("app.delivery.ProviderRouter.execute_delivery", stub_execute)
    request_payload = delivery_request_payload(generation_id="gen-respond-invalid-contract-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-invalid-contract-1",
        request_id="req-respond-invalid-contract-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 502
    payload = response.json()
    assert payload["code"] == "provider_response_contract_invalid"
    assert payload["details"]["route"] == "respond"
    assert payload["details"]["provider"] == "gemini"
    ledger_row = fake_database_state.ledger_rows["req-respond-invalid-contract-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_response_contract_invalid"


def test_respond_route_maps_provider_timeout_to_explicit_adapter_error(client, fake_database_state, monkeypatch) -> None:
    async def stub_execute(self, payload):
        raise ProviderRequestError(
            code="provider_timeout",
            message="Gemini request timed out.",
            status_code=504,
            details={
                "provider": "gemini",
                "model": "gemini-2.0-flash",
            },
            retryable=True,
        )

    monkeypatch.setattr("app.delivery.ProviderRouter.execute_delivery", stub_execute)
    request_payload = delivery_request_payload(generation_id="gen-respond-timeout-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-timeout-1",
        request_id="req-respond-timeout-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 504
    payload = response.json()
    assert payload["code"] == "provider_timeout"
    assert payload["retryable"] is True
    assert "test-gemini-api-key" not in json.dumps(payload)
    ledger_row = fake_database_state.ledger_rows["req-respond-timeout-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_timeout"


def test_respond_route_returns_structured_failure_when_delivery_route_is_disabled(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_delivery_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_ROUTE_ENABLED", "false")
    clear_settings_cache()
    monkeypatch.setattr("app.delivery.ProviderRouter.execute_delivery", stub_execute)
    request_payload = delivery_request_payload(generation_id="gen-respond-disabled-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-respond-disabled-1",
        request_id="req-respond-disabled-1",
    )

    response = client.post("/v1/respond", content=body, headers=headers)

    assert response.status_code == 503
    payload = response.json()
    assert payload["code"] == "delivery_route_disabled"
    assert payload["details"]["fallback_allowed"] is True
    assert calls == []
    ledger_row = fake_database_state.ledger_rows["req-respond-disabled-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["cache_status"] == "bypass"