from __future__ import annotations

from app.cache import (
    build_delivery_cache_key,
    build_interpretation_cache_document,
    build_interpretation_cache_key,
)
from app.models import DeliveryRequest, InterpretationRequest


def interpretation_payload(generation_id: str) -> dict[str, object]:
    return {
        "request_type": "media_prompt_interpretation",
        "generation_id": generation_id,
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.  ",
        "input": {
            "teacher_prompt": "  Buatkan handout pecahan untuk kelas 5. ",
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


def delivery_payload(generation_id: str, preview_summary: str) -> dict[str, object]:
    return {
        "request_type": "media_delivery_response",
        "generation_id": generation_id,
        "model": "llm-gateway",
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
                "content": None,
                "recommended_project": None,
            },
            "preview_summary": preview_summary,
            "teacher_delivery_summary": "Bagikan file setelah pengantar singkat.",
            "generation_summary": "Handout untuk penguatan konsep pecahan.",
        },
    }


def test_interpretation_cache_document_excludes_generation_id() -> None:
    payload = InterpretationRequest.model_validate(interpretation_payload("gen-100"))

    document = build_interpretation_cache_document(
        payload,
        provider="Gemini",
        model="gemini-2.0-flash",
    )

    assert document["route"] == "interpret"
    assert document["provider"] == "gemini"
    assert document["instruction"] == "Return exactly one JSON object."
    assert document["input"]["teacher_prompt"] == "Buatkan handout pecahan untuk kelas 5."
    assert "generation_id" not in document


def test_interpretation_cache_key_ignores_generation_id_for_same_semantic_request() -> None:
    first_payload = InterpretationRequest.model_validate(interpretation_payload("gen-100"))
    second_payload = InterpretationRequest.model_validate(interpretation_payload("gen-200"))

    first_key = build_interpretation_cache_key(
        first_payload,
        provider="gemini",
        model="gemini-2.0-flash",
    )
    second_key = build_interpretation_cache_key(
        second_payload,
        provider="gemini",
        model="gemini-2.0-flash",
    )

    assert first_key == second_key


def test_delivery_cache_key_changes_when_semantic_payload_changes() -> None:
    first_payload = DeliveryRequest.model_validate(
        delivery_payload("gen-300", "Ringkasan distribusi pertama.")
    )
    second_payload = DeliveryRequest.model_validate(
        delivery_payload("gen-301", "Ringkasan distribusi kedua.")
    )

    first_key = build_delivery_cache_key(
        first_payload,
        provider="gemini",
        model="gemini-2.0-flash",
    )
    second_key = build_delivery_cache_key(
        second_payload,
        provider="gemini",
        model="gemini-2.0-flash",
    )

    assert first_key != second_key