from __future__ import annotations

import hashlib
import hmac
import json
from pathlib import Path

from tests.helpers import cleanup_artifact, signed_request_content


def test_health_endpoint_reports_supported_formats(client) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["supported_formats"] == ["docx", "pdf", "pptx"]
    assert response.json()["contracts"]["generation_spec"] == "media_generation_spec.v1"
    assert response.json()["contracts"]["response"] == "media_generator_response.v1"


def test_generate_pdf_returns_artifact_metadata_with_page_count(client) -> None:
    body, headers, _ = signed_request_content("pdf")

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    assert payload["schema_version"] == "media_generator_response.v1"
    assert payload["data"]["artifact_delivery"]["kind"] == "temporary_path"
    assert payload["data"]["artifact_metadata"]["export_format"] == "pdf"
    assert payload["data"]["artifact_metadata"]["mime_type"] == "application/pdf"
    assert payload["data"]["artifact_metadata"]["page_count"] >= 1
    assert Path(payload["data"]["artifact_metadata"]["artifact_locator"]["value"]).is_file()

    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_docx_returns_artifact_metadata_without_requiring_page_count(client) -> None:
    body, headers, _ = signed_request_content("docx")

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["artifact_metadata"]["export_format"] == "docx"
    assert payload["data"]["artifact_metadata"]["extension"] == "docx"
    assert payload["data"]["artifact_metadata"]["mime_type"] == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    assert payload["data"]["artifact_metadata"]["page_count"] is None
    assert Path(payload["data"]["artifact_metadata"]["artifact_locator"]["value"]).is_file()

    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_pptx_returns_artifact_metadata_with_slide_count(client) -> None:
    body, headers, _ = signed_request_content("pptx")

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["data"]["artifact_metadata"]["export_format"] == "pptx"
    assert payload["data"]["artifact_metadata"]["extension"] == "pptx"
    assert payload["data"]["artifact_metadata"]["slide_count"] == 4
    assert payload["data"]["artifact_delivery"]["kind"] == "temporary_path"
    assert Path(payload["data"]["artifact_metadata"]["artifact_locator"]["value"]).is_file()

    cleanup_artifact(payload["data"]["artifact_metadata"])


def test_generate_rejects_invalid_signature(client) -> None:
    body, headers, _ = signed_request_content("pdf")
    headers["X-Klass-Signature"] = "0" * 64

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 401
    assert response.json()["schema_version"] == "media_generator_response.v1"
    assert response.json()["status"] == "failed"
    assert response.json()["error"]["code"] == "signature_invalid"
    assert response.json()["error"]["laravel_error_code_hint"] == "python_service_unavailable"


def test_generate_rejects_generation_id_mismatch_with_structured_error_contract(client) -> None:
    body, headers, payload = signed_request_content("pdf")
    payload["generation_id"] = "another-generation-id"

    mutated_body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    timestamp = headers["X-Klass-Request-Timestamp"]
    headers["X-Klass-Signature"] = hmac.new(
        b"test-shared-secret",
        timestamp.encode("utf-8") + b"." + mutated_body,
        hashlib.sha256,
    ).hexdigest()

    response = client.post("/v1/generate", content=mutated_body, headers=headers)

    assert response.status_code == 422
    assert response.json()["status"] == "failed"
    assert response.json()["error"]["code"] == "generation_id_mismatch"
    assert response.json()["error"]["laravel_error_code_hint"] == "artifact_invalid"
