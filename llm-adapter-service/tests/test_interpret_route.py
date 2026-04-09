from __future__ import annotations

import hashlib
import hmac
import json
import time

from app.cache import INTERPRETATION_CACHE_TABLE_NAME
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


def interpretation_request_payload(
    *,
    generation_id: str = "gen-interpret-1",
    preferred_output_type: str = "pdf",
    request_type: str = "media_prompt_interpretation",
    teacher_prompt: str = "Buatkan handout pecahan untuk kelas 5.",
) -> dict[str, object]:
    return {
        "request_type": request_type,
        "generation_id": generation_id,
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "teacher_prompt": teacher_prompt,
            "preferred_output_type": preferred_output_type,
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


def valid_interpretation_response_payload() -> dict[str, object]:
    return {
        "schema_version": "media_prompt_understanding.v1",
        "teacher_prompt": "Buatkan handout pecahan untuk kelas 5.",
        "language": "id",
        "teacher_intent": {
            "type": "generate_learning_media",
            "goal": "Create a printable worksheet for classroom use.",
            "preferred_delivery_mode": "digital_download",
            "requires_clarification": False,
        },
        "learning_objectives": [
            "Siswa memahami pecahan sederhana.",
        ],
        "constraints": {
            "preferred_output_type": "pdf",
            "max_duration_minutes": 40,
            "must_include": ["contoh soal"],
            "avoid": ["istilah kompleks"],
            "tone": "supportive",
        },
        "output_type_candidates": [
            {
                "type": "pptx",
                "score": 0.29,
                "reason": "Slide deck hanya alternatif sekunder.",
            },
            {
                "type": "pdf",
                "score": 0.82,
                "reason": "Format printable paling cocok untuk distribusi kelas.",
            },
            {
                "type": "docx",
                "score": 0.61,
                "reason": "Dokumen editable masih mungkin dipakai guru.",
            },
        ],
        "resolved_output_type_reasoning": "PDF paling cocok untuk materi printable yang ingin konsisten di semua perangkat.",
        "document_blueprint": {
            "title": "Handout Pecahan Kelas 5",
            "summary": "Ringkasan pecahan dasar untuk pengantar dan latihan singkat.",
            "sections": [
                {
                    "title": "Konsep Dasar",
                    "purpose": "Memperkenalkan pecahan sederhana.",
                    "bullets": ["Pembilang", "Penyebut"],
                    "estimated_length": "short",
                }
            ],
        },
        "subject_context": {
            "subject_name": "Matematika",
            "subject_slug": "matematika",
        },
        "sub_subject_context": {
            "sub_subject_name": "Pecahan",
            "sub_subject_slug": "pecahan",
        },
        "target_audience": {
            "label": "Siswa kelas 5",
            "level": "elementary",
            "age_range": "10-11",
        },
        "requested_media_characteristics": {
            "tone": "supportive",
            "format_preferences": ["printable", "structured"],
            "visual_density": "medium",
        },
        "assets": [],
        "assessment_or_activity_blocks": [],
        "teacher_delivery_summary": "Gunakan handout ini untuk pengantar lalu lanjutkan ke latihan.",
        "confidence": {
            "score": 0.91,
            "label": "high",
            "rationale": "Prompt jelas dan langsung menyebut kebutuhan printable handout.",
        },
        "fallback": {
            "triggered": False,
            "reason_code": None,
            "action": None,
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
            route="interpret",
            generation_id=generation_id,
            requested_model=requested_model,
            model=model,
            raw_completion=raw_completion,
            usage=ProviderUsage(
                input_tokens=1000,
                output_tokens=500,
                total_tokens=1500,
                latency_ms=24.5,
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


def test_interpret_route_returns_validated_payload_and_records_cache_and_ledger(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_interpretation_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setattr("app.interpretation.ProviderRouter.execute_interpretation", stub_execute)
    request_payload = interpretation_request_payload(generation_id="gen-interpret-success-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-interpret-success-1",
        request_id="req-interpret-success-1",
    )

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["schema_version"] == "media_prompt_understanding.v1"
    assert [candidate["type"] for candidate in payload["output_type_candidates"]] == ["pdf", "docx", "pptx"]
    assert response.headers["X-Klass-LLM-Provider"] == "gemini"
    assert response.headers["X-Klass-LLM-Model"] == "gemini-2.0-flash"
    assert response.headers["X-Klass-LLM-Primary-Provider"] == "gemini"
    assert response.headers["X-Klass-LLM-Fallback-Used"] == "false"
    assert calls == ["gen-interpret-success-1"]
    assert len(fake_database_state.cache_tables[INTERPRETATION_CACHE_TABLE_NAME]) == 1
    ledger_row = fake_database_state.ledger_rows["req-interpret-success-1"]
    assert ledger_row["final_status"] == "success"
    assert ledger_row["cache_status"] == "miss"
    assert ledger_row["error_code"] is None


def test_interpret_route_reuses_cache_across_generations_with_same_semantic_request(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_interpretation_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setattr("app.interpretation.ProviderRouter.execute_interpretation", stub_execute)

    first_payload = interpretation_request_payload(generation_id="gen-cache-1")
    first_body, first_headers = build_signed_request(
        first_payload,
        generation_id="gen-cache-1",
        request_id="req-cache-1",
    )
    first_response = client.post("/v1/interpret", content=first_body, headers=first_headers)

    second_payload = interpretation_request_payload(generation_id="gen-cache-2")
    second_body, second_headers = build_signed_request(
        second_payload,
        generation_id="gen-cache-2",
        request_id="req-cache-2",
    )
    second_response = client.post("/v1/interpret", content=second_body, headers=second_headers)

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert second_response.headers["X-Klass-LLM-Provider"] == "gemini"
    assert second_response.headers["X-Klass-LLM-Model"] == "gemini-2.0-flash"
    assert second_response.headers["X-Klass-LLM-Primary-Provider"] == "gemini"
    assert calls == ["gen-cache-1"]
    second_ledger_row = fake_database_state.ledger_rows["req-cache-2"]
    assert second_ledger_row["cache_status"] == "hit"
    assert second_ledger_row["final_status"] == "success"


def test_interpret_route_rejects_invalid_request_type(client) -> None:
    request_payload = interpretation_request_payload(
        generation_id="gen-invalid-type-1",
        request_type="media_delivery_response",
    )
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-invalid-type-1",
        request_id="req-invalid-type-1",
    )

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["code"] == "interpret_request_type_invalid"



def test_interpret_route_rejects_unsupported_output_type_early(client, fake_database_state) -> None:
    request_payload = interpretation_request_payload(
        generation_id="gen-invalid-output-1",
        preferred_output_type="epub",
    )
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-invalid-output-1",
        request_id="req-invalid-output-1",
    )

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 422
    payload = response.json()
    assert payload["code"] == "preferred_output_type_unsupported"
    assert fake_database_state.ledger_rows == {}



def test_interpret_route_returns_backend_fallback_trigger_when_provider_payload_is_invalid(client, fake_database_state, monkeypatch) -> None:
    raw_completion = '{"schema_version":"media_prompt_understanding.v1","teacher_prompt":"partial only"}'

    async def stub_execute(self, payload):
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=raw_completion,
        )

    monkeypatch.setattr("app.interpretation.ProviderRouter.execute_interpretation", stub_execute)
    request_payload = interpretation_request_payload(generation_id="gen-invalid-contract-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-invalid-contract-1",
        request_id="req-invalid-contract-1",
    )

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["output_text"] == raw_completion
    assert payload["error"]["code"] == "provider_response_contract_invalid"
    assert payload["response_meta"]["validation_failed"] is True
    ledger_row = fake_database_state.ledger_rows["req-invalid-contract-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_response_contract_invalid"



def test_interpret_route_maps_provider_timeout_to_explicit_adapter_error(client, fake_database_state, monkeypatch) -> None:
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

    monkeypatch.setattr("app.interpretation.ProviderRouter.execute_interpretation", stub_execute)
    request_payload = interpretation_request_payload(generation_id="gen-timeout-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-timeout-1",
        request_id="req-timeout-1",
    )

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 504
    payload = response.json()
    assert payload["code"] == "provider_timeout"
    assert payload["retryable"] is True
    assert "test-gemini-api-key" not in json.dumps(payload)
    ledger_row = fake_database_state.ledger_rows["req-timeout-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_timeout"



def test_interpret_route_maps_provider_configuration_failure_to_explicit_adapter_error(client, fake_database_state, monkeypatch) -> None:
    monkeypatch.delenv("LLM_ADAPTER_GEMINI_API_KEY", raising=False)
    clear_settings_cache()
    request_payload = interpretation_request_payload(generation_id="gen-config-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-config-1",
        request_id="req-config-1",
    )

    response = client.post("/v1/interpret", content=body, headers=headers)

    assert response.status_code == 503
    payload = response.json()
    assert payload["code"] == "provider_config_missing"
    assert payload["details"]["missing_settings"] == ["LLM_ADAPTER_GEMINI_API_KEY"]
    ledger_row = fake_database_state.ledger_rows["req-config-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_config_missing"
