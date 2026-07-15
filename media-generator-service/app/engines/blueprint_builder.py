"""Convert a ``RenderDocument`` into a ``SlideBlueprint``.

This module bridges the existing document-model layer (frozen dataclasses
produced by :func:`app.document_model.build_render_document`) and the new
Pydantic-based blueprint schema consumed by all three engine pillars.

The mapping is intentionally deterministic and heuristic-driven — no LLM
calls, no randomness.  It mirrors the slide structure already produced by
:class:`app.generators.pptx_generator.PptxGenerator` so that the new engine
generates a visually equivalent deck before the template-injection and
canvas-calculator layers are wired in.

Mapping rules
-------------
1. **Title slide** — ``slide_type="title"``, title from ``RenderDocument.title``,
   subtitle from ``summary``, cards built from ``learning_objectives``
   (each objective becomes a bullet ``ContentBlock``).
2. **Content slides** — one per ``RenderSection``, ``slide_type="content"``.
   Each section's ``RenderBlock`` list becomes a single ``Card`` whose
   ``body_blocks`` are converted to ``ContentBlock`` Pydantic models.
3. **Assessment slide** — if ``activity_blocks`` is non-empty, one slide with
   ``slide_type="assessment"``.  Each ``RenderActivity`` becomes a ``Card``
   with the activity title as ``heading`` and the instructions as a
   paragraph ``ContentBlock``.
"""
from __future__ import annotations

from app.document_model import RenderDocument, RenderBlock
from app.engines.blueprint import (
    Card,
    ContentBlock,
    DeckMeta,
    Slide,
    SlideBlueprint,
)


def build_slide_blueprint(render_document: RenderDocument) -> SlideBlueprint:
    """Transform a ``RenderDocument`` into a validated ``SlideBlueprint``.

    The function is pure — it reads from *render_document* and returns a new
    blueprint without side-effects.  It intentionally does **not** accept a
    ``GenerationSpec`` directly; callers should use
    :func:`app.document_model.build_render_document` first, keeping the
    ``GenerationSpec`` → ``RenderDocument`` step reusable for other formats.

    If *render_document* specifies a ``template_id`` it is forwarded to
    ``SlideBlueprint.theme_id``, allowing Flutter / Gateway requests to
    select a different PPTX master template.
    """
    deck_meta = DeckMeta(
        title=render_document.title,
        summary=render_document.summary,
        language=render_document.language,
        audience_level=render_document.audience_level,
        tone=render_document.tone,
        learning_objectives=list(render_document.learning_objectives),
    )

    slides: list[Slide] = []
    slides.append(_build_title_slide(render_document))
    slides.extend(_build_content_slides(render_document))
    slides.extend(_build_assessment_slide(render_document))

    blueprint = SlideBlueprint(
        deck_meta=deck_meta,
        slides=slides,
    )

    # Forward the caller's template preference into the blueprint.
    if render_document.template_id:
        blueprint.theme_id = render_document.template_id

    return blueprint


def _build_title_slide(render_document: RenderDocument) -> Slide:
    """Title slide: subtitle = summary, cards = learning objectives."""
    cards: list[Card] = []

    if render_document.learning_objectives:
        cards.append(Card(
            body_blocks=[
                ContentBlock(kind="bullet", content=obj)
                for obj in render_document.learning_objectives
            ],
        ))

    summary = render_document.summary
    subtitle = None
    if summary:
        subtitle = summary if len(summary) <= 500 else summary[:497] + "..."

    return Slide(
        slide_type="title",
        title=render_document.title,
        subtitle=subtitle,
        cards=cards if cards else [Card(body_blocks=[ContentBlock(kind="paragraph", content=summary)])],
    )


def _build_content_slides(render_document: RenderDocument) -> list[Slide]:
    """One content slide per ``RenderSection``."""
    slides: list[Slide] = []

    for section in render_document.sections:
        cards: list[Card] = []

        if section.blocks:
            cards.append(Card(
                body_blocks=[_convert_block(block) for block in section.blocks],
            ))
        else:
            cards.append(Card(
                body_blocks=[ContentBlock(kind="paragraph", content=section.purpose)],
            ))

        slides.append(Slide(
            slide_type="content",
            title=section.title,
            cards=cards,
        ))

    return slides


def _build_assessment_slide(render_document: RenderDocument) -> list[Slide]:
    """Assessment slide from ``activity_blocks`` (omitted if empty)."""
    if not render_document.activity_blocks:
        return []

    cards: list[Card] = [
        Card(
            heading=activity.title,
            body_blocks=[
                ContentBlock(kind="paragraph", content=activity.instructions),
            ],
        )
        for activity in render_document.activity_blocks
    ]

    return [Slide(
        slide_type="assessment",
        title="Aktivitas dan Penilaian",
        cards=cards,
    )]


def _convert_block(block: RenderBlock) -> ContentBlock:
    """Map a ``RenderBlock`` dataclass to a ``ContentBlock`` Pydantic model.

    The ``kind`` values (``"paragraph"``, ``"bullet"``, ``"checklist"``,
    ``"note"``) are identical between the two models, so no remapping is
    needed — only the container type changes from frozen dataclass to
    Pydantic ``StrictModel``.
    """
    return ContentBlock(kind=block.kind, content=block.content)
