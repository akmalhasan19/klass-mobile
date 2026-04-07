from __future__ import annotations

from pathlib import Path

from tests.helpers import cleanup_artifact, signed_request_content


def test_health_endpoint_reports_supported_formats(client) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["supported_formats"] == ["docx", "pdf"]
    assert response.json()["contracts"]["generation_spec"] == "media_generation_spec.v1"


def test_generate_pdf_returns_artifact_metadata_with_page_count(client) -> None:
    body, headers, _ = signed_request_content("pdf")

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    assert payload["artifact_metadata"]["export_format"] == "pdf"
    assert payload["artifact_metadata"]["mime_type"] == "application/pdf"
    assert payload["artifact_metadata"]["page_count"] >= 1
    assert Path(payload["artifact_metadata"]["artifact_locator"]["value"]).is_file()

    cleanup_artifact(payload["artifact_metadata"])


def test_generate_docx_returns_artifact_metadata_without_requiring_page_count(client) -> None:
    body, headers, _ = signed_request_content("docx")

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert payload["artifact_metadata"]["export_format"] == "docx"
    assert payload["artifact_metadata"]["extension"] == "docx"
    assert payload["artifact_metadata"]["mime_type"] == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    assert payload["artifact_metadata"]["page_count"] is None
    assert Path(payload["artifact_metadata"]["artifact_locator"]["value"]).is_file()

    cleanup_artifact(payload["artifact_metadata"])


def test_generate_rejects_invalid_signature(client) -> None:
    body, headers, _ = signed_request_content("pdf")
    headers["X-Klass-Signature"] = "0" * 64

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "signature_invalid"


def test_generate_rejects_unimplemented_pptx_export(client) -> None:
    body, headers, _ = signed_request_content("pptx")

    response = client.post("/v1/generate", content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "unsupported_export_format"
