from __future__ import annotations

import hashlib
import hmac
import json
import time
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from app.contracts import (
    ARTIFACT_METADATA_VERSION,
    GENERATION_SPEC_VERSION,
    SIGNATURE_ALGORITHM,
)
from app.models import GenerateRequest


def sample_request_payload(export_format: str = "pdf") -> dict[str, object]:
    document_mode = "slide_deck" if export_format == "pptx" else "document"
    unit_type = "slide" if export_format == "pptx" else "page"

    return {
        "generation_id": f"generation-{export_format}-001",
        "generation_spec": {
            "schema_version": GENERATION_SPEC_VERSION,
            "source_interpretation_schema_version": "media_prompt_understanding.v1",
            "export_format": export_format,
            "title": "Handout Pecahan Kelas 5",
            "language": "id",
            "summary": "Handout ringkas untuk memperkenalkan pecahan senilai dan latihan dasar.",
            "learning_objectives": [
                "Siswa mengenali pecahan senilai.",
                "Siswa mencoba latihan pecahan dasar.",
            ],
            "sections": [
                {
                    "title": "Tujuan Belajar",
                    "purpose": "Menjelaskan target belajar utama sebelum latihan dimulai.",
                    "body_blocks": [
                        {"type": "bullet", "content": "Memahami pecahan senilai"},
                        {"type": "bullet", "content": "Menyelesaikan latihan dasar"},
                    ],
                    "emphasis": "short",
                },
                {
                    "title": "Contoh dan Latihan",
                    "purpose": "Memberi contoh singkat lalu latihan mandiri.",
                    "body_blocks": [
                        {"type": "paragraph", "content": "Tampilkan satu contoh pecahan bergambar."},
                        {"type": "checklist", "content": "Kerjakan tiga soal latihan."},
                    ],
                    "emphasis": "medium",
                },
            ],
            "layout_hints": {
                "document_mode": document_mode,
                "visual_density": "medium",
                "section_count": 2,
                "asset_count": 1,
                "assessment_block_count": 1,
            },
            "style_hints": {
                "tone": "encouraging",
                "audience_level": "elementary",
                "format_preferences": ["printable", export_format],
            },
            "page_or_slide_structure": {
                "unit_type": unit_type,
                "total_units": 4,
                "opening_unit": True,
                "section_units": 2,
                "closing_unit": True,
            },
            "content_context": {
                "subject_context": {"subject_name": "Matematika", "subject_slug": "matematika"},
                "sub_subject_context": {"sub_subject_name": "Pecahan", "sub_subject_slug": "pecahan"},
                "target_audience": {"label": "Siswa kelas 5", "level": "elementary", "age_range": "10-11"},
            },
            "assets": [
                {"type": "diagram", "description": "Ilustrasi lingkaran pecahan", "required": True},
            ],
            "assessment_or_activity_blocks": [
                {
                    "title": "Latihan Mandiri",
                    "type": "activity",
                    "instructions": "Kerjakan tiga soal pecahan senilai secara mandiri.",
                }
            ],
            "teacher_delivery_summary": "Gunakan handout ini untuk pengantar materi lalu lanjutkan ke latihan mandiri.",
            "contract_versions": {
                "generator_output_metadata": ARTIFACT_METADATA_VERSION,
            },
        },
        "contracts": {
            "generation_spec": GENERATION_SPEC_VERSION,
            "artifact_metadata": ARTIFACT_METADATA_VERSION,
        },
    }


def sample_request(export_format: str = "pdf") -> GenerateRequest:
    return GenerateRequest.model_validate(sample_request_payload(export_format))


def signed_request_content(
    export_format: str = "pdf",
    secret: str = "test-shared-secret",
    timestamp: int | None = None,
) -> tuple[bytes, dict[str, str], dict[str, object]]:
    payload = sample_request_payload(export_format)
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    issued_at = str(timestamp if timestamp is not None else int(time.time()))
    signature = hmac.new(
        secret.encode("utf-8"),
        issued_at.encode("utf-8") + b"." + body,
        hashlib.sha256,
    ).hexdigest()

    headers = {
        "Content-Type": "application/json",
        "X-Klass-Generation-Id": str(payload["generation_id"]),
        "X-Klass-Request-Timestamp": issued_at,
        "X-Klass-Signature-Algorithm": SIGNATURE_ALGORITHM,
        "X-Klass-Signature": signature,
    }

    return body, headers, payload


def cleanup_artifact(metadata: dict[str, object]) -> None:
    artifact_path = artifact_path_from_metadata(metadata)
    if artifact_path is None:
        return

    artifact_path.unlink(missing_ok=True)


def artifact_path_from_metadata(metadata: dict[str, object]) -> Path | None:
    locator = metadata.get("artifact_locator")
    if not isinstance(locator, dict):
        return None

    locator_kind = locator.get("kind")

    path_value = locator.get("value")
    if not isinstance(path_value, str) or path_value.strip() == "":
        return None

    if locator_kind == "signed_url":
        query = parse_qs(urlparse(path_value).query)
        path_value = (query.get("path") or [""])[0]

    if not isinstance(path_value, str) or path_value.strip() == "":
        return None

    return Path(path_value)
