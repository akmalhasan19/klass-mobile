"""Regenerate plan_mode, interpreted_fields, and missing_fields from an interpretation payload.

When the interpretation cache is hit, the plan_mode fields (plan_mode,
interpreted_fields, missing_fields) are returned frozen from the original
LLM response. This module re-derives these fields deterministically from the
interpretation payload's content, ensuring PLAN MODE questions are always
fresh and contextual.
"""

from __future__ import annotations

from typing import Any


# ── Content type detection ────────────────────────────────────────────────

_CONTENT_TYPE_KEYWORDS: dict[str, list[str]] = {
    "slide_presentasi": ["slide", "presentasi", "powerpoint", "pptx", "tayangan"],
    "rpp": ["rpp", "rencana pelaksanaan", "lesson plan", "perencanaan pembelajaran"],
    "lembar_kerja": ["lembar kerja", "worksheet", "latihan", "praktik"],
    "penilaian": ["penilaian", "asesmen", "assessment", "soal", "ujian", "tes"],
    "silabus": ["silabus", "syllabus", "kurikulum"],
    "materi_pembelajaran": ["materi", "modul", "handout", "bahan ajar", "pelajaran", "belajar"],
}

_CONTENT_TYPE_LABELS: dict[str, str] = {
    "slide_presentasi": "slide presentasi",
    "rpp": "Rencana Pelaksanaan Pembelajaran (RPP)",
    "lembar_kerja": "lembar kerja",
    "penilaian": "penilaian/asesmen",
    "silabus": "silabus",
    "materi_pembelajaran": "materi pembelajaran",
}

_CONTENT_TYPE_REQUIRED_FIELDS: dict[str, list[str]] = {
    "slide_presentasi": ["target_audience", "output_type"],
    "rpp": ["target_audience", "learning_objectives"],
    "lembar_kerja": ["target_audience", "difficulty_level"],
    "penilaian": ["target_audience", "difficulty_level", "question_count"],
    "silabus": ["target_audience"],
    "materi_pembelajaran": ["target_audience", "output_type"],
}

_JENJANG_SUGGESTIONS = [
    "SD Kelas 1", "SD Kelas 2", "SD Kelas 3",
    "SD Kelas 4", "SD Kelas 5", "SD Kelas 6",
    "SMP Kelas 7", "SMP Kelas 8", "SMP Kelas 9",
    "SMA Kelas 10", "SMA Kelas 11", "SMA Kelas 12",
]


def _detect_content_type(payload: dict[str, Any]) -> str:
    """Detect the content type from the interpretation payload."""
    text = " ".join([
        (payload.get("teacher_prompt") or "").lower(),
        (payload.get("document_blueprint", {}).get("title") or "").lower(),
        (payload.get("document_blueprint", {}).get("summary") or "").lower(),
    ])

    best_type = "materi_pembelajaran"
    best_score = 0

    for content_type, keywords in _CONTENT_TYPE_KEYWORDS.items():
        score = sum(1 for kw in keywords if kw in text)
        if score > best_score:
            best_score = score
            best_type = content_type

    return best_type


def _is_field_present(payload: dict[str, Any], field_id: str) -> bool:
    """Check if a required field is present and non-empty in the payload."""
    if field_id == "target_audience":
        ta = payload.get("target_audience")
        if isinstance(ta, dict):
            return bool(ta.get("label"))
        return False

    if field_id == "output_type":
        constraints = payload.get("constraints", {})
        pot = constraints.get("preferred_output_type", "auto")
        return pot != "auto" and bool(pot)

    if field_id == "learning_objectives":
        lo = payload.get("learning_objectives", [])
        return isinstance(lo, list) and len(lo) > 0

    if field_id == "difficulty_level":
        interpreted = payload.get("interpreted_fields") or {}
        return bool(interpreted.get("difficulty_level"))

    if field_id == "question_count":
        interpreted = payload.get("interpreted_fields") or {}
        return interpreted.get("question_count") is not None

    return False


def _find_missing_fields(payload: dict[str, Any], content_type: str) -> list[str]:
    """Find which required fields are missing for the given content type."""
    required = _CONTENT_TYPE_REQUIRED_FIELDS.get(content_type, ["target_audience"])
    return [fid for fid in required if not _is_field_present(payload, fid)]


def _generate_missing_field(
    field_id: str,
    payload: dict[str, Any],
    content_type: str,
) -> dict[str, Any]:
    """Generate a contextual missing field question."""
    topic_hint = (payload.get("document_blueprint") or {}).get("title") or "materi ini"
    subject_hint = "pelajaran ini"
    sc = payload.get("subject_context")
    if isinstance(sc, dict) and sc.get("subject_name"):
        subject_hint = sc["subject_name"]

    label_text = _CONTENT_TYPE_LABELS.get(content_type, "media pembelajaran")

    if field_id == "target_audience":
        if content_type == "slide_presentasi":
            question = f"Slide presentasi '{topic_hint}' ini ditujukan untuk siswa jenjang/kelas mana?"
        elif content_type == "rpp":
            question = f"RPP '{topic_hint}' ini disusun untuk jenjang/kelas berapa?"
        else:
            question = f"Materi '{topic_hint}' untuk {subject_hint} ini ditujukan untuk siswa jenjang/kelas mana?"

        return {
            "field_id": "target_audience",
            "field_label": "Jenjang/Kelas",
            "priority": "required",
            "question": question,
            "suggestions": _JENJANG_SUGGESTIONS,
            "input_type": "select",
        }

    if field_id == "output_type":
        if content_type == "slide_presentasi":
            question = f"Format file apa yang Anda inginkan untuk slide '{topic_hint}' ini?"
            suggestions = [
                {"value": "pptx", "label": "PowerPoint (.pptx)"},
                {"value": "pdf", "label": "PDF (cetak)"},
            ]
        else:
            question = f"Format file apa yang Anda inginkan untuk materi '{topic_hint}' ini?"
            suggestions = [
                {"value": "pdf", "label": "PDF (cetak)"},
                {"value": "docx", "label": "Word (.docx)"},
                {"value": "pptx", "label": "PowerPoint (.pptx)"},
            ]

        return {
            "field_id": "output_type",
            "field_label": "Format Output",
            "priority": "required",
            "question": question,
            "suggestions": suggestions,
            "input_type": "select",
        }

    if field_id == "learning_objectives":
        return {
            "field_id": "learning_objectives",
            "field_label": "Tujuan Pembelajaran",
            "priority": "required",
            "question": (
                f"Apa saja tujuan pembelajaran yang ingin dicapai dari '{topic_hint}'? "
                "Contoh: Memahami konsep X, Menganalisis Y, Menerapkan Z."
            ),
            "suggestions": ["Memahami konsep...", "Menganalisis...", "Menerapkan...", "Menjelaskan..."],
            "input_type": "textarea",
        }

    if field_id == "difficulty_level":
        return {
            "field_id": "difficulty_level",
            "field_label": "Tingkat Kesulitan",
            "priority": "required",
            "question": f"Tingkat kesulitan materi '{topic_hint}' ini sebaiknya seperti apa?",
            "suggestions": [
                "Mudah (pengenalan dasar)",
                "Sedang (pemahaman konsep)",
                "Sulit (analisis dan evaluasi)",
            ],
            "input_type": "select",
        }

    if field_id == "question_count":
        return {
            "field_id": "question_count",
            "field_label": "Jumlah Soal",
            "priority": "required",
            "question": f"Berapa jumlah soal yang Anda butuhkan untuk asesmen '{topic_hint}' ini?",
            "suggestions": [10, 15, 20, 25, 30],
            "input_type": "number",
        }

    return {
        "field_id": field_id,
        "field_label": field_id.replace("_", " ").title(),
        "priority": "recommended",
        "question": f"Informasi '{field_id}' belum terdeteksi. Mohon lengkapi jika diperlukan.",
        "suggestions": [],
        "input_type": "text",
    }


def _build_interpreted_fields(payload: dict[str, Any]) -> dict[str, Any]:
    """Build interpreted_fields from the interpretation payload content.

    Preserves existing values from the payload's interpreted_fields when
    available, and only fills in what can be derived from the main payload.
    """
    # Start from the existing interpreted_fields if present
    existing = payload.get("interpreted_fields") or {}

    ta = payload.get("target_audience")
    target_audience = None
    if isinstance(ta, dict) and ta.get("label"):
        level = ta.get("level")
        target_audience = f"{ta['label']} {level}" if level else ta["label"]

    constraints = payload.get("constraints", {})
    pot = constraints.get("preferred_output_type", "auto")
    output_type = pot if pot != "auto" else None
    if output_type is None:
        candidates = payload.get("output_type_candidates", [])
        if isinstance(candidates, list) and candidates:
            output_type = candidates[0].get("type")

    sc = payload.get("subject_context")
    subject = sc.get("subject_name") if isinstance(sc, dict) else None

    db = payload.get("document_blueprint") or {}
    topic = db.get("title")

    lo = payload.get("learning_objectives")
    learning_objectives = lo if isinstance(lo, list) and lo else None

    rmc = payload.get("requested_media_characteristics") or {}

    return {
        # Prefer freshly derived values, fall back to existing
        "target_audience": target_audience or existing.get("target_audience"),
        "output_type": output_type or existing.get("output_type"),
        "subject": subject or existing.get("subject"),
        "topic": topic or existing.get("topic"),
        "learning_objectives": learning_objectives or existing.get("learning_objectives"),
        # Preserve all other fields from the original payload
        "page_count": existing.get("page_count"),
        "difficulty_level": existing.get("difficulty_level"),
        "include_activities": existing.get("include_activities"),
        "slide_count": existing.get("slide_count"),
        "question_count": existing.get("question_count"),
        "meeting_duration": existing.get("meeting_duration"),
        "teaching_method": existing.get("teaching_method"),
        "assessment_method": existing.get("assessment_method"),
        "visual_density": rmc.get("visual_density") or existing.get("visual_density"),
        "speaker_notes": existing.get("speaker_notes"),
        "question_type": existing.get("question_type"),
    }


def regenerate_plan_mode_from_interpretation(payload: dict[str, Any]) -> dict[str, Any]:
    """Re-derive plan_mode, interpreted_fields, and missing_fields from the interpretation payload.

    This is called after a **cache hit** so that PLAN MODE questions are always
    regenerated deterministically from the actual interpretation content, rather
    than returning stale frozen questions from a previous cache entry.

    Returns the updated payload dict with fresh plan_mode fields.
    """
    if not isinstance(payload, dict):
        return payload

    # ── 1. Build interpreted_fields ──────────────────────────────────────
    interpreted_fields = _build_interpreted_fields(payload)

    # ── 2. Detect content type ───────────────────────────────────────────
    content_type = _detect_content_type(payload)

    # ── 3. Find missing required fields ──────────────────────────────────
    missing_field_ids = _find_missing_fields(payload, content_type)

    # ── 4. Generate contextual missing_field questions ───────────────────
    missing_fields = [
        _generate_missing_field(fid, payload, content_type)
        for fid in missing_field_ids
    ]

    # ── 5. Derive plan_mode ──────────────────────────────────────────────
    plan_active = len(missing_fields) > 0
    reason = None
    if plan_active:
        missing_labels = [f["field_label"] for f in missing_fields]
        label_text = _CONTENT_TYPE_LABELS.get(content_type, "media pembelajaran")
        reason = (
            f"Berdasarkan analisis prompt, terdapat informasi yang belum lengkap "
            f"untuk {label_text}: {', '.join(missing_labels)}. "
            f"Silakan lengkapi informasi berikut agar media dapat dibuat dengan tepat."
        )

    confidence = payload.get("confidence") or {}
    confidence_score = confidence.get("score", 0.6) if isinstance(confidence, dict) else 0.6

    # ── 6. Update payload ────────────────────────────────────────────────
    payload["plan_mode"] = {
        "active": plan_active,
        "reason": reason,
        "detected_content_type": content_type,
        "content_type_confidence": confidence_score,
    }
    payload["interpreted_fields"] = interpreted_fields
    payload["missing_fields"] = missing_fields

    # ── 7. Update requires_clarification to match ────────────────────────
    ti = payload.get("teacher_intent")
    if isinstance(ti, dict):
        ti["requires_clarification"] = plan_active

    return payload
