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

    When ``pptx_slides`` are present on the *render_document* (from the LLM's
    explicit slide structure draft), those are mapped directly to ``Slide``
    objects preserving the LLM's ``layout_type``, bypassing the heuristic
    card-count-based layout detection.
    """
    deck_meta = DeckMeta(
        title=render_document.pptx_presentation_title or render_document.title,
        summary=render_document.summary,
        language=render_document.language,
        audience_level=render_document.audience_level,
        tone=render_document.tone,
        learning_objectives=list(render_document.learning_objectives),
        # Additive branding fields — None when the source spec omits them.
        subject=render_document.subject,
        sub_subject=render_document.sub_subject,
    )

    slides: list[Slide] = []

    if render_document.pptx_slides:
        # ── PPTX slides mode: use explicit LLM slide structures ──
        slides.extend(_build_slides_from_pptx_data(render_document))
    else:
        # ── Legacy heuristic mode ──
        slides.append(_build_title_slide(render_document))
        slides.extend(_build_content_slides(render_document))
        slides.extend(_build_assessment_slide(render_document))

    blueprint = SlideBlueprint(
        deck_meta=deck_meta,
        slides=slides,
    )

    # Forward the caller's template preference into the blueprint.
    # For PPTX slides mode, theme_suggestion from LLM takes precedence.
    if render_document.pptx_theme_suggestion:
        blueprint.theme_id = render_document.pptx_theme_suggestion
    elif render_document.template_id:
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
    """One content slide per ``RenderSection``, with splitting for long sections."""
    slides: list[Slide] = []

    for section in render_document.sections:
        cards: list[Card] = []

        if section.blocks:
            # Split blocks into chunks that fit on a single slide
            chunks = _split_blocks_into_chunks(section.blocks, max_blocks_per_slide=6)
            for chunk in chunks:
                cards.append(Card(
                    body_blocks=[_convert_block(block) for block in chunk],
                ))
        else:
            cards.append(Card(
                body_blocks=[ContentBlock(kind="paragraph", content=section.purpose)],
            ))

        # If multiple cards (split sections), create one slide per card
        if len(cards) > 1:
            for i, card in enumerate(cards):
                slide_title = f"{section.title}" if i == 0 else f"{section.title} (lanjutan)"
                slides.append(Slide(
                    slide_type="content",
                    title=slide_title,
                    cards=[card],
                ))
        else:
            slides.append(Slide(
                slide_type="content",
                title=section.title,
                cards=cards,
            ))

    return slides


def _split_blocks_into_chunks(blocks: list, max_blocks_per_slide: int = 6) -> list[list]:
    """Split a list of blocks into chunks that fit on a single slide.

    Heuristic: each slide can hold ~6 blocks comfortably at 720px height.
    Longer blocks (paragraphs) count as 2, shorter ones (bullets) as 1.
    """
    if len(blocks) <= max_blocks_per_slide:
        return [blocks]

    chunks = []
    current_chunk = []
    current_weight = 0

    for block in blocks:
        # Estimate weight: paragraphs are heavier
        weight = 2 if block.kind == "paragraph" else 1

        if current_weight + weight > max_blocks_per_slide and current_chunk:
            chunks.append(current_chunk)
            current_chunk = [block]
            current_weight = weight
        else:
            current_chunk.append(block)
            current_weight += weight

    if current_chunk:
        chunks.append(current_chunk)

    return chunks


def _convert_block(block: RenderBlock) -> ContentBlock:
    """Map a ``RenderBlock`` dataclass to a ``ContentBlock`` Pydantic model.

    The ``kind`` values (``"paragraph"``, ``"bullet"``, ``"checklist"``,
    ``"note"``) are identical between the two models, so no remapping is
    needed — only the container type changes from frozen dataclass to
    Pydantic ``StrictModel``.
    """
    return ContentBlock(kind=block.kind, content=block.content)


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


# ── Layout type mapping ────────────────────────────────────────────────────

# Map the 8-layout catalog from the LLM prompt to SlideType values.
# The layout_type is preserved in the slide's columns_hint field as a
# semantic marker, while slide_type uses the existing enum for basic
# categorization.
_LAYOUT_TO_SLIDE_TYPE: dict[str, str] = {
    "title_hero": "title",
    "section_header": "section",
    "bullet_list_icon": "content",
    "two_columns_card": "content",
    "three_columns_card": "content",
    "metric_highlight": "content",
    "timeline_process": "content",
    "quote_callout": "content",
}

_LAYOUT_TO_COLUMNS_HINT: dict[str, int | None] = {
    "title_hero": None,
    "section_header": None,
    "bullet_list_icon": 1,
    "two_columns_card": 2,
    "three_columns_card": 3,
    "metric_highlight": 3,
    "timeline_process": None,
    "quote_callout": 1,
}


def _build_slides_from_pptx_data(render_document: RenderDocument) -> list[Slide]:
    """Build slides from explicit PPTX slide structures from the LLM.

    Each ``RenderPptxSlide`` is mapped to a ``Slide`` with:
    - ``slide_type`` derived from the layout catalog
    - ``columns_hint`` set from layout semantics
    - ``cards`` built from the content items (heading + body pairs)
    - The original ``layout_type`` is stored in ``speaker_notes`` as a
      structured marker so the downstream PptxGenerator can pass it through
      to the Node.js renderer.
    """
    slides: list[Slide] = []

    for pptx_slide in render_document.pptx_slides:
        layout = pptx_slide.layout_type
        slide_type = _LAYOUT_TO_SLIDE_TYPE.get(layout, "content")
        columns_hint = _LAYOUT_TO_COLUMNS_HINT.get(layout)

        cards: list[Card] = []
        if pptx_slide.content:
            for item in pptx_slide.content:
                body_text = item.body or item.heading or "Content"
                cards.append(Card(
                    heading=item.heading if item.heading else None,
                    body_blocks=[ContentBlock(kind="paragraph", content=body_text)],
                ))
        else:
            # Slides with no content (title_hero, section_header)
            subtitle_text = pptx_slide.subtitle or render_document.summary or "Content"
            cards.append(Card(
                body_blocks=[ContentBlock(kind="paragraph", content=subtitle_text)],
            ))

        slides.append(Slide(
            slide_type=slide_type,
            title=pptx_slide.title,
            subtitle=pptx_slide.subtitle,
            cards=cards,
            columns_hint=columns_hint,
            # Store the original layout_type as a marker for downstream
            # PptxGenerator to pass through to the Node.js renderer.
            speaker_notes=f"layout_type:{layout}",
        ))

    return slides
