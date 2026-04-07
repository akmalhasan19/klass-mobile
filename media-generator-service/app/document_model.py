from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from app.models import AssessmentBlock, Asset, BodyBlock, GenerationSpec, Section


LABELS = {
    "en": {
        "summary": "Summary",
        "context": "Classroom Context",
        "subject": "Subject",
        "sub_subject": "Sub Subject",
        "audience": "Audience",
        "tone": "Tone",
        "format_preferences": "Format Preferences",
        "learning_objectives": "Learning Objectives",
        "assets": "Suggested Assets",
        "activity_blocks": "Activities and Assessments",
        "teacher_notes": "Teacher Notes",
        "required": "Required",
        "optional": "Optional",
    },
    "id": {
        "summary": "Ringkasan",
        "context": "Konteks Kelas",
        "subject": "Mata Pelajaran",
        "sub_subject": "Sub Mata Pelajaran",
        "audience": "Sasaran Belajar",
        "tone": "Nada",
        "format_preferences": "Preferensi Format",
        "learning_objectives": "Tujuan Pembelajaran",
        "assets": "Aset Pendukung",
        "activity_blocks": "Aktivitas dan Penilaian",
        "teacher_notes": "Catatan untuk Guru",
        "required": "Wajib",
        "optional": "Opsional",
    },
}


def localized_label(language: str, key: str) -> str:
    language_key = (language or "en").split("-", 1)[0].lower()
    return LABELS.get(language_key, LABELS["en"]).get(key, LABELS["en"].get(key, key.replace("_", " ").title()))


def _pick_value(candidate: dict[str, object] | None, keys: Iterable[str]) -> str | None:
    if not isinstance(candidate, dict):
        return None

    for key in keys:
        value = candidate.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()

    return None


@dataclass(frozen=True)
class RenderBlock:
    kind: str
    content: str


@dataclass(frozen=True)
class RenderSection:
    title: str
    purpose: str
    emphasis: str
    blocks: list[RenderBlock]


@dataclass(frozen=True)
class RenderAsset:
    asset_type: str
    description: str
    required: bool


@dataclass(frozen=True)
class RenderActivity:
    title: str
    activity_type: str
    instructions: str


@dataclass(frozen=True)
class RenderDocument:
    title: str
    export_format: str
    language: str
    summary: str
    tone: str
    audience_level: str
    visual_density: str
    format_preferences: list[str]
    learning_objectives: list[str]
    context_rows: list[tuple[str, str]]
    sections: list[RenderSection]
    assets: list[RenderAsset]
    activity_blocks: list[RenderActivity]
    teacher_delivery_summary: str


def _map_sections(sections: list[Section]) -> list[RenderSection]:
    rendered_sections: list[RenderSection] = []

    for section in sections:
        blocks = [RenderBlock(kind=block.type, content=block.content) for block in section.body_blocks]
        rendered_sections.append(
            RenderSection(
                title=section.title,
                purpose=section.purpose,
                emphasis=section.emphasis,
                blocks=blocks,
            )
        )

    return rendered_sections


def _map_assets(assets: list[Asset]) -> list[RenderAsset]:
    return [
        RenderAsset(asset_type=asset.type, description=asset.description, required=asset.required)
        for asset in assets
    ]


def _map_activities(activity_blocks: list[AssessmentBlock]) -> list[RenderActivity]:
    return [
        RenderActivity(
            title=block.title,
            activity_type=block.type,
            instructions=block.instructions,
        )
        for block in activity_blocks
    ]


def _context_rows(spec: GenerationSpec) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []

    subject = _pick_value(spec.content_context.subject_context, ["subject_name", "subject_slug"])
    sub_subject = _pick_value(spec.content_context.sub_subject_context, ["sub_subject_name", "sub_subject_slug"])
    audience = _pick_value(spec.content_context.target_audience, ["label", "level", "age_range"])
    format_preferences = ", ".join(spec.style_hints.format_preferences)

    if subject:
        rows.append((localized_label(spec.language, "subject"), subject))

    if sub_subject:
        rows.append((localized_label(spec.language, "sub_subject"), sub_subject))

    if audience:
        rows.append((localized_label(spec.language, "audience"), audience))

    rows.append((localized_label(spec.language, "tone"), spec.style_hints.tone))
    rows.append((localized_label(spec.language, "format_preferences"), format_preferences))

    return rows


def build_render_document(spec: GenerationSpec) -> RenderDocument:
    return RenderDocument(
        title=spec.title,
        export_format=spec.export_format,
        language=spec.language,
        summary=spec.summary,
        tone=spec.style_hints.tone,
        audience_level=spec.style_hints.audience_level,
        visual_density=spec.layout_hints.visual_density,
        format_preferences=list(spec.style_hints.format_preferences),
        learning_objectives=list(spec.learning_objectives),
        context_rows=_context_rows(spec),
        sections=_map_sections(spec.sections),
        assets=_map_assets(spec.assets),
        activity_blocks=_map_activities(spec.assessment_or_activity_blocks),
        teacher_delivery_summary=spec.teacher_delivery_summary,
    )
