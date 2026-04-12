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


def content_draft_request_payload(
    *,
    generation_id: str = "gen-draft-1",
    request_type: str = "media_content_draft",
) -> dict[str, object]:
    return {
        "request_type": request_type,
        "generation_id": generation_id,
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "resolved_output_type": "pdf",
            "interpretation": {
                "schema_version": "media_prompt_understanding.v1",
                "teacher_prompt": "Buatkan handout sistem pencernaan untuk kelas 5.",
                "language": "id",
                "teacher_intent": {
                    "type": "generate_learning_media",
                    "goal": "Create a printable classroom handout.",
                    "preferred_delivery_mode": "digital_download",
                    "requires_clarification": False,
                },
                "learning_objectives": ["Siswa memahami organ utama sistem pencernaan."],
                "constraints": {
                    "preferred_output_type": "pdf",
                    "max_duration_minutes": 45,
                    "must_include": ["contoh sederhana"],
                    "avoid": [],
                    "tone": "supportive",
                },
                "output_type_candidates": [
                    {
                        "type": "pdf",
                        "score": 0.92,
                        "reason": "Format printable paling sesuai.",
                    }
                ],
                "resolved_output_type_reasoning": "PDF paling cocok untuk handout kelas.",
                "document_blueprint": {
                    "title": "Handout Sistem Pencernaan Kelas 5",
                    "summary": "Ringkasan materi sistem pencernaan dengan contoh sederhana.",
                    "sections": [
                        {
                            "title": "Mengenal Organ Pencernaan",
                            "purpose": "Memperkenalkan urutan organ utama dan fungsinya.",
                            "bullets": ["Mulut", "Kerongkongan", "Lambung", "Usus"],
                            "estimated_length": "medium",
                        }
                    ],
                },
                "subject_context": {
                    "subject_name": "IPA",
                    "subject_slug": "ipa",
                },
                "sub_subject_context": {
                    "sub_subject_name": "Sistem Pencernaan",
                    "sub_subject_slug": "sistem-pencernaan",
                },
                "target_audience": {
                    "label": "Siswa kelas 5",
                    "level": "elementary",
                    "age_range": "10-11",
                },
                "requested_media_characteristics": {
                    "tone": "supportive",
                    "format_preferences": ["printable"],
                    "visual_density": "medium",
                },
                "assets": [],
                "assessment_or_activity_blocks": [],
                "teacher_delivery_summary": "Gunakan handout ini untuk pengantar sebelum latihan singkat.",
                "confidence": {
                    "score": 0.91,
                    "label": "high",
                    "rationale": "Prompt cukup jelas dan spesifik.",
                },
                "fallback": {
                    "triggered": False,
                    "reason_code": None,
                    "action": None,
                },
            },
        },
    }


def valid_content_draft_response_payload() -> dict[str, object]:
    return {
        "schema_version": "media_content_draft.v1",
        "title": "Handout Sistem Pencernaan Kelas 5",
        "summary": "Handout ini menjelaskan organ utama sistem pencernaan, alur makanan, dan contoh kebiasaan menjaga kesehatan pencernaan.",
        "learning_objectives": [
            "Siswa mengenali organ utama pada sistem pencernaan.",
            "Siswa menjelaskan fungsi dasar setiap organ pencernaan.",
        ],
        "sections": [
            {
                "title": "Mengenal Organ Pencernaan",
                "purpose": "Memperkenalkan urutan organ utama dan fungsinya.",
                "body_blocks": [
                    {
                        "type": "paragraph",
                        "content": "Makanan pertama kali masuk ke tubuh melalui mulut. Di dalam mulut, makanan dikunyah agar menjadi lebih halus dan mudah ditelan. Setelah itu, makanan bergerak melalui kerongkongan menuju lambung untuk dicerna lebih lanjut.",
                    },
                    {
                        "type": "bullet",
                        "content": "Lambung membantu menghancurkan makanan dengan bantuan cairan pencernaan.",
                    },
                ],
                "emphasis": "medium",
            }
        ],
        "teacher_delivery_summary": "Gunakan handout ini untuk memperkenalkan alur makanan di dalam tubuh sebelum diskusi kelas.",
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
            route="respond",
            generation_id=generation_id,
            requested_model=requested_model,
            model=model,
            raw_completion=raw_completion,
            usage=ProviderUsage(
                input_tokens=700,
                output_tokens=260,
                total_tokens=960,
                latency_ms=18.4,
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


def test_draft_route_returns_validated_payload_and_records_cache_and_ledger(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_content_draft_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setattr("app.draft.ProviderRouter.execute_content_draft", stub_execute)
    request_payload = content_draft_request_payload(generation_id="gen-draft-success-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-draft-success-1",
        request_id="req-draft-success-1",
    )

    response = client.post("/v1/draft", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["schema_version"] == "media_content_draft.v1"
    assert payload["fallback"]["triggered"] is False
    assert payload["sections"][0]["body_blocks"][0]["type"] == "paragraph"
    assert response.headers["X-Klass-LLM-Provider"] == "gemini"
    assert response.headers["X-Klass-LLM-Model"] == "gemini-2.0-flash"
    assert response.headers["X-Klass-LLM-Primary-Provider"] == "gemini"
    assert response.headers["X-Klass-LLM-Fallback-Used"] == "false"
    assert calls == ["gen-draft-success-1"]
    assert len(fake_database_state.cache_tables[DELIVERY_CACHE_TABLE_NAME]) == 1
    ledger_row = fake_database_state.ledger_rows["req-draft-success-1"]
    assert ledger_row["final_status"] == "success"
    assert ledger_row["cache_status"] == "miss"
    assert ledger_row["request_type"] == "media_content_draft"


def test_draft_route_reuses_cache_across_generations_with_same_semantic_request(client, fake_database_state, monkeypatch) -> None:
    calls: list[str] = []

    async def stub_execute(self, payload):
        calls.append(payload.generation_id)
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=json.dumps(valid_content_draft_response_payload(), ensure_ascii=False, separators=(",", ":")),
        )

    monkeypatch.setattr("app.draft.ProviderRouter.execute_content_draft", stub_execute)

    first_payload = content_draft_request_payload(generation_id="gen-draft-cache-1")
    first_body, first_headers = build_signed_request(
        first_payload,
        generation_id="gen-draft-cache-1",
        request_id="req-draft-cache-1",
    )
    first_response = client.post("/v1/draft", content=first_body, headers=first_headers)

    second_payload = content_draft_request_payload(generation_id="gen-draft-cache-2")
    second_body, second_headers = build_signed_request(
        second_payload,
        generation_id="gen-draft-cache-2",
        request_id="req-draft-cache-2",
    )
    second_response = client.post("/v1/draft", content=second_body, headers=second_headers)

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert calls == ["gen-draft-cache-1"]
    second_ledger_row = fake_database_state.ledger_rows["req-draft-cache-2"]
    assert second_ledger_row["cache_status"] == "hit"
    assert second_ledger_row["final_status"] == "success"


def test_draft_route_rejects_invalid_request_type(client) -> None:
    request_payload = content_draft_request_payload(
        generation_id="gen-draft-invalid-type-1",
        request_type="media_delivery_response",
    )
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-draft-invalid-type-1",
        request_id="req-draft-invalid-type-1",
    )

    response = client.post("/v1/draft", content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["code"] == "draft_request_type_invalid"


def test_draft_route_rejects_missing_interpretation_payload_early(client, fake_database_state) -> None:
    request_payload = content_draft_request_payload(generation_id="gen-draft-no-interpretation-1")
    request_payload["input"]["interpretation"] = ""
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-draft-no-interpretation-1",
        request_id="req-draft-no-interpretation-1",
    )

    response = client.post("/v1/draft", content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["code"] == "draft_interpretation_invalid"
    assert fake_database_state.ledger_rows == {}


def test_draft_route_returns_structured_failure_when_provider_payload_is_invalid(client, fake_database_state, monkeypatch) -> None:
    raw_completion = '{"schema_version":"media_content_draft.v1","title":"partial only"}'

    async def stub_execute(self, payload):
        return build_execution_result(
            generation_id=payload.generation_id,
            raw_completion=raw_completion,
        )

    monkeypatch.setattr("app.draft.ProviderRouter.execute_content_draft", stub_execute)
    request_payload = content_draft_request_payload(generation_id="gen-draft-invalid-contract-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-draft-invalid-contract-1",
        request_id="req-draft-invalid-contract-1",
    )

    response = client.post("/v1/draft", content=body, headers=headers)

    assert response.status_code == 502
    payload = response.json()
    assert payload["code"] == "provider_response_contract_invalid"
    assert payload["details"]["route"] == "respond"
    assert payload["details"]["provider"] == "gemini"
    ledger_row = fake_database_state.ledger_rows["req-draft-invalid-contract-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_response_contract_invalid"


def test_draft_route_maps_provider_timeout_to_explicit_adapter_error(client, fake_database_state, monkeypatch) -> None:
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

    monkeypatch.setattr("app.draft.ProviderRouter.execute_content_draft", stub_execute)
    request_payload = content_draft_request_payload(generation_id="gen-draft-timeout-1")
    body, headers = build_signed_request(
        request_payload,
        generation_id="gen-draft-timeout-1",
        request_id="req-draft-timeout-1",
    )

    response = client.post("/v1/draft", content=body, headers=headers)

    assert response.status_code == 504
    payload = response.json()
    assert payload["code"] == "provider_timeout"
    assert payload["retryable"] is True
    ledger_row = fake_database_state.ledger_rows["req-draft-timeout-1"]
    assert ledger_row["final_status"] == "failed"
    assert ledger_row["error_code"] == "provider_timeout"